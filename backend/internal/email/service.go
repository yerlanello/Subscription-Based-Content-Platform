package email

import (
	"fmt"
	"log"
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
	if s.host == "" {
		log.Printf("[EMAIL DEV] To=%s | Subject=%s | Body=%s", to, subject, body)
		return nil
	}

	msg := strings.Join([]string{
		fmt.Sprintf("From: %s", s.from),
		fmt.Sprintf("To: %s", to),
		fmt.Sprintf("Subject: %s", subject),
		"MIME-Version: 1.0",
		"Content-Type: text/html; charset=UTF-8",
		"",
		body,
	}, "\r\n")

	addr := fmt.Sprintf("%s:%s", s.host, s.port)
	var auth smtp.Auth
	if s.user != "" {
		auth = smtp.PlainAuth("", s.user, s.pass, s.host)
	}
	return smtp.SendMail(addr, auth, s.from, []string{to}, []byte(msg))
}

func (s *Service) SendVerificationEmail(to, username, token string) error {
	link := fmt.Sprintf("%s/verify-email?token=%s", s.appURL, token)
	subject := "Подтвердите ваш email"
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
  <p style="color:#6b7280;font-size:13px">Ссылка действительна 24 часа. Если вы не регистрировались — проигнорируйте это письмо.</p>
</body>
</html>`, username, link)
	return s.send(to, subject, body)
}

func (s *Service) SendPasswordResetEmail(to, username, token string) error {
	link := fmt.Sprintf("%s/reset-password?token=%s", s.appURL, token)
	subject := "Сброс пароля"
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
  <p style="color:#6b7280;font-size:13px">Ссылка действительна 1 час. Если вы не запрашивали сброс пароля — проигнорируйте это письмо.</p>
</body>
</html>`, username, link)
	return s.send(to, subject, body)
}
