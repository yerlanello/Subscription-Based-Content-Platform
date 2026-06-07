package email

import (
	"crypto/tls"
	"fmt"
	"log"
	"net"
	"net/mail"
	"net/smtp"
	"strings"
)

type Service struct {
	host   string
	port   string
	user   string
	pass   string
	from   string
	appURL string
}

func NewService(host, port, user, pass, from, appURL string) *Service {
	if port == "" {
		port = "587"
	}
	if from == "" {
		from = "noreply@app.com"
	}
	if appURL == "" {
		appURL = "http://localhost:3000"
	}
	return &Service{host: host, port: port, user: user, pass: pass, from: from, appURL: appURL}
}

func (s *Service) send(to, subject, body string) error {
	// No SMTP host configured — print to log (dev mode)
	if s.host == "" {
		log.Printf("[EMAIL DEV] To=%s | Subject=%s | Body=%s", to, subject, body)
		return nil
	}

	addr := net.JoinHostPort(s.host, s.port)

	msg := strings.Join([]string{
		fmt.Sprintf("From: %s", s.from),
		fmt.Sprintf("To: %s", to),
		fmt.Sprintf("Subject: %s", subject),
		"MIME-Version: 1.0",
		"Content-Type: text/html; charset=UTF-8",
		"",
		body,
	}, "\r\n")

	auth := smtp.PlainAuth("", s.user, s.pass, s.host)

	// Try STARTTLS first (port 587)
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		return fmt.Errorf("dial %s: %w", addr, err)
	}

	client, err := smtp.NewClient(conn, s.host)
	if err != nil {
		conn.Close()
		return fmt.Errorf("smtp client: %w", err)
	}
	defer client.Close()

	// Upgrade to TLS via STARTTLS
	tlsCfg := &tls.Config{ServerName: s.host}
	if err := client.StartTLS(tlsCfg); err != nil {
		return fmt.Errorf("starttls: %w", err)
	}

	if err := client.Auth(auth); err != nil {
		return fmt.Errorf("smtp auth: %w", err)
	}

	// MAIL FROM must be bare address, not "Name <addr>" format
	fromAddr := s.from
	if addr, err := mail.ParseAddress(s.from); err == nil {
		fromAddr = addr.Address
	}
	if err := client.Mail(fromAddr); err != nil {
		return fmt.Errorf("smtp MAIL FROM: %w", err)
	}
	if err := client.Rcpt(to); err != nil {
		return fmt.Errorf("smtp RCPT TO: %w", err)
	}

	w, err := client.Data()
	if err != nil {
		return fmt.Errorf("smtp DATA: %w", err)
	}
	if _, err = fmt.Fprint(w, msg); err != nil {
		return fmt.Errorf("smtp write body: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("smtp close body: %w", err)
	}

	return client.Quit()
}

func (s *Service) SendVerificationEmail(to, username, token string) error {
	link := fmt.Sprintf("%s/verify-email?token=%s", s.appURL, token)
	body := fmt.Sprintf(`<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;max-width:560px;margin:40px auto;padding:0 16px">
  <h2 style="color:#7c3aed">Добро пожаловать, %s!</h2>
  <p>Пожалуйста, подтвердите ваш email-адрес, нажав на кнопку ниже.</p>
  <p style="margin:32px 0">
    <a href="%s"
       style="background:#7c3aed;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:600">
      Подтвердить email
    </a>
  </p>
  <p style="color:#6b7280;font-size:13px">Ссылка действительна 24 часа.</p>
</body>
</html>`, username, link)
	return s.send(to, "Подтвердите ваш email — Xabarla", body)
}

func (s *Service) SendPasswordResetEmail(to, username, token string) error {
	link := fmt.Sprintf("%s/reset-password?token=%s", s.appURL, token)
	body := fmt.Sprintf(`<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;max-width:560px;margin:40px auto;padding:0 16px">
  <h2 style="color:#7c3aed">Сброс пароля</h2>
  <p>Привет, %s! Мы получили запрос на сброс пароля вашего аккаунта.</p>
  <p style="margin:32px 0">
    <a href="%s"
       style="background:#7c3aed;color:#fff;padding:12px 24px;border-radius:8px;text-decoration:none;font-weight:600">
      Сбросить пароль
    </a>
  </p>
  <p style="color:#6b7280;font-size:13px">Ссылка действительна 1 час.</p>
</body>
</html>`, username, link)
	return s.send(to, "Сброс пароля — Xabarla", body)
}
