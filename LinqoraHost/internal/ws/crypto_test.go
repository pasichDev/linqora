package ws

import (
	"bytes"
	"testing"
)

func TestCryptoFlow(t *testing.T) {
	secret := "super-secret-key"
	key := DeriveKey(secret)
	
	if len(key) != 32 {
		t.Errorf("Expected 32-byte key, got %d", len(key))
	}

	plainText := []byte("hello linqora e2ee")
	
	cipherText, err := Encrypt(plainText, key)
	if err != nil {
		t.Fatalf("Encryption failed: %v", err)
	}

	if len(cipherText) == 0 {
		t.Error("Ciphertext should not be empty")
	}

	decrypted, err := Decrypt(cipherText, key)
	if err != nil {
		t.Fatalf("Decryption failed: %v", err)
	}

	if !bytes.Equal(plainText, decrypted) {
		t.Errorf("Expected %s, got %s", plainText, decrypted)
	}
}

func TestDecryptWithWrongKey(t *testing.T) {
	key1 := DeriveKey("secret1")
	key2 := DeriveKey("secret2")
	
	plainText := []byte("confidential data")
	cipherText, _ := Encrypt(plainText, key1)

	_, err := Decrypt(cipherText, key2)
	if err == nil {
		t.Error("Decryption with wrong key should fail")
	}
}

func TestDecryptInvalidData(t *testing.T) {
	key := DeriveKey("secret")
	_, err := Decrypt("invalid-base64-!@#", key)
	if err == nil {
		t.Error("Decryption of invalid base64 should fail")
	}
	
	_, err = Decrypt("YQ==", key) // Valid base64 but too short for GCM
	if err == nil {
		t.Error("Decryption of too short data should fail")
	}
}
