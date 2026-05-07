package certutils

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

// CertInfo contains extracted certificate information
type CertInfo struct {
	Issuer         string
	Subject        string
	SelfSigned     bool
	ExpirationDate time.Time
	IsValid        bool
	Organization   string
	CommonName     string
}

// IsDevelopmentCertificate checks if certificate is development/test/self-signed
func IsDevelopmentCertificate(certPath string) (bool, *CertInfo, error) {
	certData, err := os.ReadFile(certPath)
	if err != nil {
		return false, nil, fmt.Errorf("failed to read certificate file: %w", err)
	}

	info, err := parseCertificate(certData)
	if err != nil {
		return false, nil, fmt.Errorf("failed to parse certificate: %w", err)
	}

	isDev := info.SelfSigned ||
		containsDevKeywords(info.Organization) ||
		containsDevKeywords(info.CommonName) ||
		info.ExpirationDate.Sub(time.Now()) < (365*24*time.Hour)

	return isDev, info, nil
}

// parseCertificate parses certificate data and extracts useful information
func parseCertificate(certData []byte) (*CertInfo, error) {
	block, _ := pem.Decode(certData)
	if block == nil || block.Type != "CERTIFICATE" {
		return nil, errors.New("failed to decode PEM block containing certificate")
	}

	cert, err := x509.ParseCertificate(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse certificate: %w", err)
	}

	info := &CertInfo{
		Issuer:         cert.Issuer.String(),
		Subject:        cert.Subject.String(),
		ExpirationDate: cert.NotAfter,
		IsValid:        time.Now().After(cert.NotBefore) && time.Now().Before(cert.NotAfter),
		Organization:   strings.Join(cert.Subject.Organization, " "),
		CommonName:     cert.Subject.CommonName,
	}

	info.SelfSigned = (cert.Issuer.String() == cert.Subject.String())

	return info, nil
}

// containsDevKeywords checks if string contains development-related keywords
func containsDevKeywords(s string) bool {
	s = strings.ToLower(s)
	keywords := []string{"dev", "test", "develop", "local", "staging", "debug"}

	for _, keyword := range keywords {
		if strings.Contains(s, keyword) {
			return true
		}
	}
	return false
}

// ValidateCertKeyPair ensures that the certificate and private key files exist
// AND form a valid pair. Previously this only checked file existence; using
// tls.LoadX509KeyPair catches mismatches (e.g. cert replaced with a forged one).
func ValidateCertKeyPair(certPath, keyPath string) error {
	_, err := tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		return fmt.Errorf("cert/key pair validation failed: %w", err)
	}
	return nil
}
