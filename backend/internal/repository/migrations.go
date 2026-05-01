package repository

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// RunMigrations applies all *.sql files from the migrations directory in order.
// It creates a schema_migrations table to track which files have been applied.
func RunMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	_, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			filename TEXT PRIMARY KEY,
			applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)
	`)
	if err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	// If schema_migrations is empty but users table already exists —
	// this is an existing DB. Mark migrations as applied only if their
	// tables already exist; otherwise let the main loop run them.
	var count int
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM schema_migrations`).Scan(&count)
	if count == 0 {
		var usersExists bool
		pool.QueryRow(ctx, `
			SELECT EXISTS (
				SELECT FROM information_schema.tables WHERE table_name = 'users'
			)
		`).Scan(&usersExists)

		if usersExists {
			dir := "migrations"
			entries, _ := os.ReadDir(dir)
			marked := 0
			for _, e := range entries {
				if e.IsDir() || !strings.HasSuffix(e.Name(), ".sql") {
					continue
				}
				sqlBytes, err := os.ReadFile(filepath.Join(dir, e.Name()))
				if err != nil {
					continue
				}
				if migrationTablesExist(ctx, pool, string(sqlBytes)) {
					pool.Exec(ctx, `
						INSERT INTO schema_migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING
					`, e.Name())
					marked++
				}
			}
			log.Printf("schema_migrations: existing DB detected, marked %d migrations as applied", marked)
			// Fall through to main loop — any unmarked migrations will be run below.
		}
	}

	dir := "migrations"
	entries, err := os.ReadDir(dir)
	if err != nil {
		// migrations dir not found — skip (e.g. running tests)
		log.Printf("warn: migrations dir not found, skipping: %v", err)
		return nil
	}

	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)

	for _, f := range files {
		var count int
		err := pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM schema_migrations WHERE filename = $1`, f,
		).Scan(&count)
		if err != nil {
			return fmt.Errorf("check migration %s: %w", f, err)
		}
		if count > 0 {
			// Marked as applied — but verify the tables actually exist.
			// If they don't, the migration was recorded prematurely; re-apply it.
			sqlBytes, _ := os.ReadFile(filepath.Join(dir, f))
			if migrationTablesExist(ctx, pool, string(sqlBytes)) {
				continue // truly already applied
			}
			log.Printf("migration %s marked applied but tables missing — re-applying", f)
			pool.Exec(ctx, `DELETE FROM schema_migrations WHERE filename = $1`, f)
		}

		sql, err := os.ReadFile(filepath.Join(dir, f))
		if err != nil {
			return fmt.Errorf("read migration %s: %w", f, err)
		}

		if _, err := pool.Exec(ctx, string(sql)); err != nil {
			return fmt.Errorf("apply migration %s: %w", f, err)
		}

		if _, err := pool.Exec(ctx,
			`INSERT INTO schema_migrations (filename) VALUES ($1)`, f,
		); err != nil {
			return fmt.Errorf("record migration %s: %w", f, err)
		}

		log.Printf("migration applied: %s", f)
	}

	return nil
}

// migrationTablesExist returns true if every table declared in the SQL already
// exists in the database. Migrations with no CREATE TABLE statements are
// considered already applied (e.g. index-only migrations).
func migrationTablesExist(ctx context.Context, pool *pgxpool.Pool, sql string) bool {
	re := regexp.MustCompile(`(?i)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\w+)`)
	matches := re.FindAllStringSubmatch(sql, -1)
	if len(matches) == 0 {
		return true // no tables — assume safe to mark applied
	}
	for _, m := range matches {
		var exists bool
		pool.QueryRow(ctx,
			`SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = $1)`,
			strings.ToLower(m[1]),
		).Scan(&exists)
		if !exists {
			return false
		}
	}
	return true
}
