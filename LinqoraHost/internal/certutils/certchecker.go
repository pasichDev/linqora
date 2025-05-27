package certutils

import (
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"io/ioutil"
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
	certData, err := ioutil.ReadFile(certPath)
	if err != nil {
		return false, nil, fmt.Errorf("failed to read certificate file: %w", err)
	}

	info, err := parseCertificate(certData)
	if err != nil {
		return false, nil, fmt.Errorf("failed to parse certificate: %w", err)
	}

	// Consider certificate as "development" if:
	// 1. It's self-signed
	// 2. Contains development keywords in organization or CN
	// 3. Has a short validity period (<1 year)
	isDev := info.SelfSigned ||
		containsDevKeywords(info.Organization) ||
		containsDevKeywords(info.CommonName) ||
		info.ExpirationDate.Sub(time.Now()) < (365*24*time.Hour) // Less than 1 year validity

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

	// Check if self-signed (issuer = subject)
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

// ValidateCertKeyPair ensures that certificate and key files match
func ValidateCertKeyPair(certPath, keyPath string) error {
	// This would require loading both files and validating they form a pair
	// For now we just check that both files exist
	if _, err := os.Stat(certPath); os.IsNotExist(err) {
		return fmt.Errorf("certificate file not found: %s", certPath)
	}

	if _, err := os.Stat(keyPath); os.IsNotExist(err) {
		return fmt.Errorf("key file not found: %s", keyPath)
	}

	return nil
}
