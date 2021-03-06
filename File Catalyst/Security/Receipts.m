//
//  Receipts.m
//  Caravelle
//
//  Created by Nuno on 28/08/15.
//  Copyright (c) 2015 Nuno Brum. All rights reserved.
//



#if (APP_IS_SANDBOXED==1)

#include <openssl/x509.h>
#include <openssl/asn1.h>
#include <openssl/pkcs7.h>
#include "Payload.h"

//#import <Foundation/Foundation.h>
//#import <Cocoa/Cocoa.h>

BOOL NSString_UTF8STRING_compare(ReceiptAttribute_t *receipt, const NSString *other) {
    // The value on the receipt has two bytes at the beginning. I don't understand why
    BOOL answer = NO;
    const char *utfString = [other UTF8String];
    if (utfString)
        answer = (0 == memcmp(receipt->value.buf+2, utfString, receipt->value.size-2));
    return answer;
}

/*long decode_receipt_element(char **value, const ReceiptAttribute_t *receipt) {
    long type = receipt->type;
    
    switch (type) {
        case 2: // UTF8STRING
        case 3:
        case 19:
        case 1702:
        case 1703:
        case 1705:
            break;
        case 21: // IA5STRING
        case 1704:
        case 1706:
        case 1708:
        case 1712:
            break;
        case 1701: // INTEGER
            break;
        case 4: // Series of Bytes
            break;
        case 5: // 20 bytes SHA-1 digest
        default:
            break;
    }
    return type;
}
*/

int validateAppReceipt () {
    int answer = 173; // Problem with recognizing receipt.
    
    // Locate the receipt
    NSURL *receiptURL;
    @try {
        receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    }
    @catch (NSException *exception) {
        receiptURL = [[NSBundle mainBundle] URLForResource:@"receipt" withExtension:@"" subdirectory:@"/Contents/_MASReceipt"];
    }
    @finally {
        
    }
    
    NSString *path = receiptURL.path;
    const BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil];
    if (!exists) {
        NSLog(@"validateAppReceipt: Couldn't find receipt at %@", path);
        return answer;
    }
    const char *cpath = [[path stringByStandardizingPath] fileSystemRepresentation];
    FILE *fp = fopen(cpath, "rb");
    if (!fp) return answer;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    PKCS7 *p7 = d2i_PKCS7_fp(fp, NULL);
    fclose(fp);
    
    if (!p7) return answer; // TODO:!!!!! check the error to return here if decoding fails.
    
    
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    if (!receipt) {
        /* No local receipt -- handle the error. */
        return answer;
    }
    
    
    NSURL *certificateURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
    NSData *certificateData = [NSData dataWithContentsOfURL:certificateURL];
    // Get it from : https://www.apple.com/appleca/AppleIncRootCertificate.cer
    
    
    if (certificateData )
    {
        int verified = 1;
        int result = 0;
        OpenSSL_add_all_digests(); // Required for PKCS7_verify to work
        X509_STORE *store = X509_STORE_new();
        if (store)
        {
            /* ... Load the Apple root certificate into b_X509 ... */
            const uint8_t *certificateBytes = (uint8_t *)(certificateData.bytes);
            X509 *certificate = d2i_X509(NULL, &certificateBytes, (long)certificateData.length);
            if (certificate)
            {
                // Adding CA Apple Root Certificate
                X509_STORE_add_cert(store, certificate);
                // Here is where magic happens
                BIO *payload = BIO_new(BIO_s_mem());
                result = PKCS7_verify(p7, NULL, store, NULL, payload, 0);
                // No need to keep payload since data is kept in the p7->d structure
                BIO_free(payload);
                
                X509_free(certificate);
            }
        }
        X509_STORE_free(store);
        EVP_cleanup();
        // Balances OpenSSL_add_all_digests (), per http://www.openssl.org/docs/crypto/OpenSSL_add_all_algorithms.html
        
        
        if ( result == verified) {
            struct pkcs7_st *contents = p7->d.sign->contents;
            if (PKCS7_type_is_data(contents))
                
#pragma clang diagnostic pop

            {
                ASN1_OCTET_STRING *octets = contents->d.data;
                
                /* The receipt payload and its size. */
                /* ... Load the payload from the receipt file into pld and set pld_sz to the payload size ... */
                
                void *pld = octets->data;
                size_t pld_sz = octets->length;
                
                //
                /* Variables used to parse the payload. Both data types are declared in Payload.h. */
                Payload_t *payload = NULL;
                asn_dec_rval_t rval;
                
                 
                /* Parse the buffer using the decoder function generated by asn1c.  The payload variable will contain the receipt attributes. */
                rval = asn_DEF_Payload.ber_decoder(NULL, &asn_DEF_Payload, (void **)&payload, pld, pld_sz, 0);
                
                
                // Now decoding the ASN.1 packet
                /* Variables used to store the receipt attributes. */
                OCTET_STRING_t *bundle_id = NULL;
                OCTET_STRING_t *bundle_version = NULL;
                OCTET_STRING_t *opaque = NULL;
                OCTET_STRING_t *hash = NULL;
                
                NSDictionary *mainInfo = [[NSBundle mainBundle] infoDictionary];
                
                answer = 0; // Now assuming that it will go well
                /* Iterate over the receipt attributes, saving the values needed to compute the GUID hash. */
                size_t i;
                for (i = 0; i < payload->list.count; i++) {
                    ReceiptAttribute_t *entry;
                    
                    entry = payload->list.array[i];
                    
                    switch (entry->type) {
                        case 2:  // Bundle Identifier : UTF8STRING
                            // This corresponds to the value of CFBundleIdentifier in the Info.plist file.
                            bundle_id = &entry->value;
                            if (NO == NSString_UTF8STRING_compare(entry, mainInfo[@"CFBundleIdentifier"])) {
                                NSLog(@"Error Validating Receipt. Expected Identifier '%@'", mainInfo[@"CFBundleIdentifier"]);
                                answer = 173; // Signal an error
                            }
                            
                            break;
                            
                        case 3: // App Version : UTF8STRING
                            //This corresponds to the value of CFBundleVersion (in iOS) or
                            // CFBundleShortVersionString (in OS X) in the Info.plist.
                            bundle_version = &entry->value;
                            if (NO == NSString_UTF8STRING_compare(entry, mainInfo[@"CFBundleShortVersionString"])) {
                                NSLog(@"Error Validating Receipt. Expected version '%@'. Ignoring", mainInfo[@"CFBundleShortVersionString"]);
                                //answer = 173; // Signal an error
                            }
                            break;
                            
                        case 4: // Opaque Value : Serie of Bytes
                            // An opaque value used, with other data, to compute the SHA-1 hash during validation.
                            opaque = &entry->value;
                            break;
                            
                        case 5: // SHA-1 Hash : 20-byte SHA-1 digest
                            // A SHA-1 hash, used to validate the receipt.
                            hash = &entry->value;
                            break;
                            
                        case 17: // In-App Purchase Receipt
                            /*In the JSON file, the value of this key is an array containing all in-app purchase receipts. 
                              In the ASN.1 file, there are multiple fields that all have type 17, each of which contains a 
                             single in-app purchase receipt.
                             
                             The in-app purchase receipt for a consumable product is added to the receipt when the purchase 
                             is made. It is kept in the receipt until your app finishes that transaction. After that point, 
                             it is removed from the receipt the next time the receipt is updated—for example, when the user 
                             makes another purchase or if your app explicitly refreshes the receipt.
                             
                             The in-app purchase receipt for a non-consumable product, auto-renewable subscription, 
                             non-renewing subscription, or free subscription remains in the receipt indefinitely. */
                            break;
                            
                        case 19: // Original Application Version
                             /*The version of the app that was originally purchased.
                             ASN.1 Field Value UTF8STRING
                             This corresponds to the value of CFBundleVersion (in iOS) or CFBundleShortVersionString (in OS X) in the Info.plist file when the purchase was originally made.
                             
                             In the sandbox environment, the value of this field is always “1.0”.
                             
                             Receipts prior to June 20, 2013 omit this field. It is populated on all new receipts, regardless of OS version. If you need the field but it is missing, manually refresh the receipt using the SKReceiptRefreshRequest class.
                             
                             Receipt Expiration Date
                             The date that the app receipt expires. */
                            break;
                             
                             /*ASN.1 Field Type 21
                             
                             ASN.1 Field Value IA5STRING, interpreted as an RFC 3339 date
                             
                             JSON Field Name expiration_date
                             
                             JSON Field Value IA5STRING, interpreted as an RFC 3339 date
                             
                             This key is present only for apps purchased through the Volume Purchase Program. If this key is not present, the receipt does not expire.
                             
                             When validating a receipt, compare this date to the current date to determine whether the receipt is expired. Do not try to use this date to calculate any other information, such as the time remaining before expiration.
                             
                             In-App Purchase Receipt Fields
                             
                             Quantity
                             The number of items purchased.
                             
                             ASN.1 Field Type 1701
                             
                             ASN.1 Field Value INTEGER
                             
                             JSON Field Name quantity
                             
                             JSON Field Value string, interpreted as an integer
                             
                             This value corresponds to the quantity property of the SKPayment object stored in the transaction’s payment property.
                             
                             Product Identifier
                             The product identifier of the item that was purchased.
                             
                             ASN.1 Field Type 1702
                             
                             ASN.1 Field Value UTF8STRING
                             
                             JSON Field Name product_id
                             
                             JSON Field Value string
                             
                             This value corresponds to the productIdentifier property of the SKPayment object stored in the transaction’s payment property.
                             
                             Transaction Identifier
                             The transaction identifier of the item that was purchased.
                             
                             ASN.1 Field Type 1703
                             
                             ASN.1 Field Value UTF8STRING
                             
                             JSON Field Name transaction_id
                             
                             JSON Field Value string
                             
                             This value corresponds to the transaction’s transactionIdentifier property.
                             
                             Original Transaction Identifier
                             For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier.
                             
                             ASN.1 Field Type 1705
                             
                             ASN.1 Field Value UTF8STRING
                             
                             JSON Field Name original_transaction_id
                             
                             JSON Field Value string
                             
                             This value corresponds to the original transaction’s transactionIdentifier property.
                             
                             All receipts in a chain of renewals for an auto-renewable subscription have the same value for this field.
                             
                             Purchase Date
                             The date and time that the item was purchased.
                             
                             ASN.1 Field Type 1704
                             
                             ASN.1 Field Value IA5STRING, interpreted as an RFC 3339 date
                             
                             JSON Field Name purchase_date
                             
                             JSON Field Value string, interpreted as an RFC 3339 date
                             
                             This value corresponds to the transaction’s transactionDate property.
                             
                             For a transaction that restores a previous transaction, the purchase date is the date of the restoration. Use Original Purchase Date to get the date of the original transaction.
                             
                             In an auto-renewable subscription receipt, this is always the date when the subscription was purchased or renewed, regardless of whether the transaction has been restored.
                             
                             Original Purchase Date
                             For a transaction that restores a previous transaction, the date of the original transaction.
                             
                             ASN.1 Field Type 1706
                             
                             ASN.1 Field Value IA5STRING, interpreted as an RFC 3339 date
                             
                             JSON Field Name original_purchase_date
                             
                             JSON Field Value string, interpreted as an RFC 3339 date
                             
                             This value corresponds to the original transaction’s transactionDate property.
                             
                             In an auto-renewable subscription receipt, this indicates the beginning of the subscription period, even if the subscription has been renewed.
                             
                             Subscription Expiration Date
                             The expiration date for the subscription, expressed as the number of milliseconds since January 1, 1970, 00:00:00 GMT.
                             
                             ASN.1 Field Type 1708
                             
                             ASN.1 Field Value IA5STRING, interpreted as an RFC 3339 date
                             
                             JSON Field Name expires_date
                             
                             JSON Field Value number
                             
                             This key is only present for auto-renewable subscription receipts.
                             
                             Cancellation Date
                             For a transaction that was canceled by Apple customer support, the time and date of the cancellation.
                             
                             ASN.1 Field Type 1712
                             
                             ASN.1 Field Value IA5STRING, interpreted as an RFC 3339 date
                             
                             JSON Field Name cancellation_date
                             
                             JSON Field Value string, interpreted as an RFC 3339 date
                             
                             Treat a canceled receipt the same as if no purchase had ever been made.
                             
                             App Item ID
                             A string that the App Store uses to uniquely identify the application that created the transaction.
                             
                             ASN.1 Field Type (none)
                             
                             ASN.1 Field Value (none)
                             
                             JSON Field Name app_item_id
                             
                             JSON Field Value string
                             
                             If your server supports multiple applications, you can use this value to differentiate between them.
                             
                             Apps are assigned an identifier only in the production environment, so this key is not present for receipts created in the test environment.
                             
                             This field is not present for Mac apps.
                             
                             See also Bundle Identifier.
                             
                             External Version Identifier
                             An arbitrary number that uniquely identifies a revision of your application.
                             
                             ASN.1 Field Type (none)
                             
                             ASN.1 Field Value (none)
                             
                             JSON Field Name version_external_identifier
                             
                             JSON Field Value string
                             
                             This key is not present for receipts created in the test environment.
                             
                             Web Order Line Item ID
                             The primary key for identifying subscription purchases.
                             
                             ASN.1 Field Type 1711
                             
                             ASN.1 Field Value INTEGER
                             
                             JSON Field Name web_order_line_item_id
                             
                             JSON Field Value string*/
                    }
                }
                
                /* For additional security, you may verify the fingerprint of the root certificate and verify the OIDs of the intermediate certificate and signing certificate. The OID in the certificate policies extension of the intermediate certificate is (1 2 840 113635 100 5 6 1), and the marker OID of the signing certificate is (1 2 840 113635 100 6 11 1). */
                
                // Check the LSMinimumSystemVersion :
                // See: xcdoc://?url=developer.apple.com/library/mac/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#
                
                // Verify if Signed by Apple
                
                // If it fails the local signature, a check with the apple store can be attempted
                //See:xcdoc://?url=developer.apple.com/library/mac/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html#
                
                // Verify that the bundle identifier matches
                
                // Verify that the Version matches : Use the CFBundleShortVersionString of the InfoPlist.strings :
                // See : xcdoc://?url=developer.apple.com/library/mac/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#
                
                // Compute the GUID
                //TODO:!!!!!!!!!!!
                //===============================================
//                UInt8 *guid = NULL;
//                size_t guid_sz;
//                
//                /* Declare and initialize an EVP context for OpenSSL. */
//                EVP_MD_CTX evp_ctx;
//                EVP_MD_CTX_init(&evp_ctx);
//                
//                /* A buffer for result of the hash computation. */
//                UInt8 digest[20];
//                
//                /* Set up the EVP context to compute a SHA-1 digest. */
//                EVP_DigestInit_ex(&evp_ctx, EVP_sha1(), NULL);
//                
//                /* Concatenate the pieces to be hashed.  They must be concatenated in this order. */
//                EVP_DigestUpdate(&evp_ctx, guid, guid_sz);
//                EVP_DigestUpdate(&evp_ctx, opaque->buf, opaque->size);
//                EVP_DigestUpdate(&evp_ctx, bundle_id->buf, bundle_id->size);
//                
//                /* Compute the hash, saving the result into the digest variable. */
//                EVP_DigestFinal_ex(&evp_ctx, digest, NULL);
            }
        }
    }
    PKCS7_free(p7);
    

    
    // Return Success
    return answer;
}

#endif
