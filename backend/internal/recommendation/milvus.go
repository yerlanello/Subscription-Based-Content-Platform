package recommendation

import (
	"context"
	"fmt"
	"log"

	"github.com/milvus-io/milvus-sdk-go/v2/client"
	"github.com/milvus-io/milvus-sdk-go/v2/entity"
)

const (
	VectorDim      = 390 // 384 text + 6 category one-hot
	PostCollection = "post_vectors"
	UserCollection = "user_vectors"
)

type MilvusClient struct {
	c client.Client
}

func NewMilvusClient(ctx context.Context, addr string, apiKey ...string) (*MilvusClient, error) {
	cfg := client.Config{Address: addr}
	if len(apiKey) > 0 && apiKey[0] != "" {
		cfg.APIKey = apiKey[0]
	}
	c, err := client.NewClient(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("milvus connect: %w", err)
	}
	mc := &MilvusClient{c: c}
	if err := mc.ensureCollections(ctx); err != nil {
		return nil, fmt.Errorf("milvus init collections: %w", err)
	}
	return mc, nil
}

func (m *MilvusClient) ensureCollections(ctx context.Context) error {
	for _, name := range []string{PostCollection, UserCollection} {
		has, err := m.c.HasCollection(ctx, name)
		if err != nil {
			return err
		}
		if has {
			// Make sure it's loaded
			if err := m.c.LoadCollection(ctx, name, false); err != nil {
				log.Printf("milvus: load collection %s: %v", name, err)
			}
			continue
		}

		schema := entity.NewSchema().
			WithName(name).
			WithField(entity.NewField().
				WithName("id").
				WithDataType(entity.FieldTypeVarChar).
				WithMaxLength(36).
				WithIsPrimaryKey(true).
				WithIsAutoID(false)).
			WithField(entity.NewField().
				WithName("vector").
				WithDataType(entity.FieldTypeFloatVector).
				WithDim(VectorDim))

		if err := m.c.CreateCollection(ctx, schema, 1); err != nil {
			return fmt.Errorf("create collection %s: %w", name, err)
		}

		idx, err := entity.NewIndexHNSW(entity.COSINE, 16, 256)
		if err != nil {
			return err
		}
		if err := m.c.CreateIndex(ctx, name, "vector", idx, false); err != nil {
			return fmt.Errorf("create index %s: %w", name, err)
		}
		if err := m.c.LoadCollection(ctx, name, false); err != nil {
			return fmt.Errorf("load collection %s: %w", name, err)
		}
		log.Printf("milvus: created collection %s", name)
	}
	return nil
}

// UpsertVector inserts or updates a vector by id.
func (m *MilvusClient) UpsertVector(ctx context.Context, collection, id string, vec []float32) error {
	ids := entity.NewColumnVarChar("id", []string{id})
	vecs := entity.NewColumnFloatVector("vector", VectorDim, [][]float32{vec})
	_, err := m.c.Upsert(ctx, collection, "", ids, vecs)
	return err
}

// GetVector fetches a single vector by id. Returns nil, nil if not found.
func (m *MilvusClient) GetVector(ctx context.Context, collection, id string) ([]float32, error) {
	expr := fmt.Sprintf(`id == "%s"`, id)
	results, err := m.c.Query(ctx, collection, nil, expr, []string{"vector"})
	if err != nil {
		return nil, err
	}
	for _, col := range results {
		if col.Name() == "vector" {
			vecCol, ok := col.(*entity.ColumnFloatVector)
			if !ok {
				continue
			}
			data := vecCol.Data()
			if len(data) > 0 {
				return data[0], nil
			}
		}
	}
	return nil, nil
}

// SearchSimilar finds the topK most similar vectors to queryVec.
func (m *MilvusClient) SearchSimilar(ctx context.Context, collection string, queryVec []float32, topK int) ([]string, error) {
	sp, err := entity.NewIndexHNSWSearchParam(64)
	if err != nil {
		return nil, err
	}
	results, err := m.c.Search(
		ctx, collection, nil, "",
		[]string{"id"},
		[]entity.Vector{entity.FloatVector(queryVec)},
		"vector", entity.COSINE, topK, sp,
	)
	if err != nil {
		return nil, err
	}

	var ids []string
	for _, r := range results {
		col, ok := r.IDs.(*entity.ColumnVarChar)
		if !ok {
			continue
		}
		ids = append(ids, col.Data()...)
	}
	return ids, nil
}

func (m *MilvusClient) Close() {
	m.c.Close()
}
