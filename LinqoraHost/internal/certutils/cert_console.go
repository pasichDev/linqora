package certutils

import "fmt"

// IsValidCertificate checks the validity of the certificate and displays appropriate messages
func IsValidCertificate(certFile string) bool {
	isDev, certInfo, err := IsDevelopmentCertificate(certFile)
	if err != nil {
		fmt.Printf("Warning: Failed to analyze certificate: %v\n", err)
		return false
	}

	if !certInfo.IsValid {
		fmt.Println("┌──────────────────────────────────────────────────────┐")
		fmt.Println("│                   SECURITY WARNING                   │")
		fmt.Println("├──────────────────────────────────────────────────────┤")
		fmt.Println("│   TLS is DISABLED — the certificate is expired!      │")
		fmt.Println("└──────────────────────────────────────────────────────┘")
		return false
	}

	if isDev {
		fmt.Println("┌──────────────────────────────────────────────────────┐")
		fmt.Println("│                   SECURITY WARNING                   │")
		fmt.Println("├──────────────────────────────────────────────────────┤")
		fmt.Println("│ TLS enabled with untrusted development certificates  │")
		fmt.Println("│ Mobile clients must allow self-signed certificates   │")
		fmt.Printf("│ Expires: %-43s │\n", certInfo.ExpirationDate.Format("2006-01-02"))
		fmt.Println("└──────────────────────────────────────────────────────┘")
		return true
	}

	// If the certificate is valid and not self-signed, we display a success message
	fmt.Println("┌──────────────────────────────────────────────────────┐")
	fmt.Println("│                   SECURITY ENABLED                   │")
	fmt.Println("├──────────────────────────────────────────────────────┤")
	fmt.Printf("│ Organization: %-40s \n", certInfo.Organization)
	fmt.Println("└──────────────────────────────────────────────────────┘")

	return true
}
