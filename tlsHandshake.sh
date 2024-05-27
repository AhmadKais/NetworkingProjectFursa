#!/bin/bash

# Step 1: Send Client Hello
response=$(curl -s -X POST -H "Content-Type: application/json" -d '{"version": "1.3", "cipherSuites": ["TLS_AES_128_GCM_SHA256", "TLS_CHACHA20_POLY1305_SHA256"], "message": "Client Hello"}' http://$1/clienthello)
session_id=$(echo $response | jq -r '.sessionID')
server_cert=$(echo $response | jq -r '.serverCert')

# Step 2: Verify Server Certificate
openssl verify -CAfile /home/ahmadkais/Downloads/cert-ca-aws.pem $server_cert
if [ $? -ne 0 ]; then
    echo "Server Certificate is invalid."
    exit 5
fi

# Step 3: Generate Master Key
master_key=$(openssl rand -base64 32)

# Step 4: Encrypt Master Key
encrypted_master_key=$(openssl smime -encrypt -aes-256-cbc -in <(echo $master_key) -outform DER $server_cert | base64 -w 0)

# Step 5: Send Encrypted Master Key
response=$(curl -s -X POST -H "Content-Type: application/json" -d '{"sessionID": "'$session_id'", "masterKey": "'$encrypted_master_key'", "sampleMessage": "Hi server, please encrypt me and send to client!"}' http://$1/keyexchange)
encrypted_sample_message=$(echo $response | jq -r '.encryptedSampleMessage')

# Step 6: Verify Encrypted Sample Message
decoded_encrypted_sample_message=$(echo $encrypted_sample_message | base64 -d)
decrypted_sample_message=$(echo "Hi server, please encrypt me and send to client!" | openssl enc -d -aes-256-cbc -pbkdf2 -k $master_key)
if [ "$decrypted_sample_message" != "$decoded_encrypted_sample_message" ]; then
    echo "Server symmetric encryption using the exchanged master-key has failed."
    exit 6
fi

echo "Client-Server TLS handshake has been completed successfully."

