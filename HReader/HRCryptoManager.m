//
//  HRCryptoManager.m
//  HReader
//
//  Created by Caleb Davenport on 5/31/12.
//  Copyright (c) 2012 MITRE Corporation. All rights reserved.
//

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>

#import "HRCryptoManager.h"

#import "SSKeychain.h"

// keychain keys

static NSString * const HRKeychainService = @"org.mitre.hreader.security";
static NSString * const HRSecurityQuestionsKeychainAccount = @"security_questions";
static NSString * const HRSecurityAnswersKeychainAccount = @"security_answers";
static NSString * const HRPasscodeKeychainAccount = @"passcode";
static NSString * const HRSharedKeyPasscodeKeychainAccount = @"shared_key_passcode";
static NSString * const HRSharedKeySecurityAnswersKeychainAccount = @"shared_key_security_answers";

// static variables

static NSString *_temporaryPasscode = nil;
static NSString *_temporaryKey = nil;
static NSArray *_temporaryQuestions = nil;
static NSArray *_temporaryAnswers = nil;

// function prototypes

static NSData * HRCryptoManagerHashString(NSString *string);
static NSData * HRCryptoManagerHashData(NSData *data);
static NSData * HRCryptoManagerEncrypt_private(NSData *data, NSString *key);
static NSData * HRCryptoManagerDecrypt_private(NSData *data, NSString *key);

// function definitions

static NSData * HRCryptoManagerHashString(NSString *string) {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return HRCryptoManagerHashData(data);
}

static NSData * HRCryptoManagerHashData(NSData *data) {
    void *buffer = malloc(CC_SHA512_DIGEST_LENGTH);
    if (buffer == nil) { return nil; }
    CC_SHA512([data bytes], [data length], buffer);
    return [NSData dataWithBytesNoCopy:buffer length:CC_SHA512_DIGEST_LENGTH];
}

static NSData * HRCryptoManagerEncrypt_private(NSData *data, NSString *key) {
    
    // get key bytes
    NSRange key_range = NSMakeRange(0, kCCKeySizeAES256);
    NSData *key_data = [HRCryptoManagerHashString(key) subdataWithRange:key_range];
    
    // get initialization vector
    NSString *iv_string = [[NSProcessInfo processInfo] globallyUniqueString];
    NSRange iv_range = NSMakeRange(0, kCCBlockSizeAES128);
    NSData *iv_data = [HRCryptoManagerHashString(iv_string) subdataWithRange:iv_range];
    
    // determine total needed space
    size_t length;
    CCCryptorStatus status = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                     [key_data bytes], [key_data length],
                                     [iv_data bytes],
                                     [data bytes], [data length],
                                     NULL, 0,
                                     &length);
    if (status != kCCBufferTooSmall) { return nil; }
    
    // create buffer
    void *buffer = malloc(length + [iv_data length]);
    if (buffer == nil) { return nil; }
    memcpy(buffer, [iv_data bytes], [iv_data length]);
    
    // perform encryption
    status = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                     [key_data bytes], [key_data length],
                     [iv_data bytes],
                     [data bytes], [data length],
                     (buffer + [iv_data length]), length,
                     &length);
    
    // cleanup and return
    if (status == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:(length + [iv_data length])];
    }
    else {
        free(buffer);
#if DEBUG
        NSLog(@"%s %d", __PRETTY_FUNCTION__, status);
#endif
        return nil;
    }
    
}

static NSData * HRCryptoManagerDecrypt_private(NSData *data, NSString *key) {
    
    // get key bytes
    NSRange key_range = NSMakeRange(0, kCCKeySizeAES256);
    NSData *key_data = [HRCryptoManagerHashString(key) subdataWithRange:key_range];
    
    // determine total needed space
    size_t length;
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                     [key_data bytes], [key_data length],
                                     [data bytes],
                                     [data bytes] + kCCBlockSizeAES128, [data length] - kCCBlockSizeAES128,
                                     NULL, 0,
                                     &length);
    
    // create buffer
    void *buffer = malloc(length);
    if (buffer == nil) { return nil; }
    
    // perform decryption
    status = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                     [key_data bytes], [key_data length],
                     [data bytes],
                     [data bytes] + kCCBlockSizeAES128, [data length] - kCCBlockSizeAES128,
                     buffer, length,
                     &length);
    
    // cleanup and return
    if (status == kCCSuccess) {
        return [NSData dataWithBytesNoCopy:buffer length:length];
    }
    else {
        free(buffer);
#if DEBUG
        NSLog(@"%s %d", __PRETTY_FUNCTION__, status);
#endif
        return nil;
    }
    
}

#pragma mark - public methods

BOOL HRCryptoManagerHasPasscode(void) {
    return ([SSKeychain passwordDataForService:HRKeychainService account:HRSharedKeyPasscodeKeychainAccount] != nil);
}

BOOL HRCryptoManagerHasSecurityQuestions(void) {
    return ([SSKeychain passwordDataForService:HRKeychainService account:HRSecurityQuestionsKeychainAccount] != nil &&
            [SSKeychain passwordDataForService:HRKeychainService account:HRSharedKeySecurityAnswersKeychainAccount]);
}

void HRCryptoManagerStoreTemporarySecurityQuestionsAndAnswers(NSArray *questions, NSArray *answers) {
    NSCAssert([questions count] == [answers count], @"The number of questions and answers must be equal");
    _temporaryQuestions = [questions copy];
    _temporaryAnswers = [answers copy];
}

void HRCryptoManagerStoreTemporaryPasscode(NSString *code) {
    _temporaryPasscode = [code copy];
}

void HRCryptoManagerFinalize(void) {
    
    // generate shared key
    _temporaryKey = [[NSProcessInfo processInfo] globallyUniqueString];
    
    // store passcode
    HRCryptoManagerUpdatePasscode(_temporaryPasscode);
    
    // store answers for security questions
    HRCryptoManagerUpdateSecurityQuestionsAndAnswers(_temporaryQuestions, _temporaryAnswers);
    
    // cleanup
    _temporaryAnswers = nil;
    _temporaryQuestions = nil;
    _temporaryPasscode = nil;
    
}

void HRCryptoManagerPurge(void) {
    _temporaryAnswers = nil;
    _temporaryQuestions = nil;
    _temporaryPasscode = nil;
    _temporaryKey = nil;
}

BOOL HRCryptoManagerUnlockWithPasscode(NSString *passcode) {
    NSCAssert(passcode, @"The passcode must not be nil");
    NSData *one = [SSKeychain passwordDataForService:HRKeychainService account:HRPasscodeKeychainAccount];
    NSData *two = HRCryptoManagerHashString(passcode);
    if ([one isEqualToData:two]) {
        NSData *encryptedKey = [SSKeychain passwordDataForService:HRKeychainService account:HRSharedKeyPasscodeKeychainAccount];
        NSData *decryptedKey = HRCryptoManagerDecrypt_private(encryptedKey, passcode);
        if (decryptedKey) {
            _temporaryKey = [[NSString alloc] initWithData:decryptedKey encoding:NSUTF8StringEncoding];
            return YES;
        }
    }
    return NO;
}

BOOL HRCryptoManagerUnlockWithAnswersForSecurityQuestions(NSArray *answers) {
    NSCAssert(answers, @"The answers must not be nil");
    NSData *one = [SSKeychain passwordDataForService:HRKeychainService account:HRSecurityAnswersKeychainAccount];
    NSData *two = [NSJSONSerialization dataWithJSONObject:answers options:0 error:nil];
    two = HRCryptoManagerHashData(one);
    if ([one isEqualToData:two]) {
        NSData *encryptedKey = [SSKeychain passwordDataForService:HRKeychainService account:HRSharedKeySecurityAnswersKeychainAccount];
        NSData *decryptedKey = HRCryptoManagerDecrypt_private(encryptedKey, [answers componentsJoinedByString:@""]);
        if (decryptedKey) {
            _temporaryKey = [[NSString alloc] initWithData:decryptedKey encoding:NSUTF8StringEncoding];
            return YES;
        }
    }
    return NO;
}

BOOL HRCryptoManagerIsUnlocked(void) {
    return (_temporaryKey != nil);
}

void HRCryptoManagerUpdatePasscode(NSString *passcode) {
    NSCAssert(passcode, @"The passcode must not be nil");
    if (_temporaryKey) {
        
        // write shared key
        NSData *keyData = [_temporaryKey dataUsingEncoding:NSUTF8StringEncoding];
        NSData *encryptedKeyData = HRCryptoManagerEncrypt_private(keyData, passcode);
        [SSKeychain setPasswordData:encryptedKeyData forService:HRKeychainService account:HRSharedKeyPasscodeKeychainAccount];
        
        // write hashed passcode
        NSData *hashedData = HRCryptoManagerHashString(passcode);
        [SSKeychain setPasswordData:hashedData forService:HRKeychainService account:HRPasscodeKeychainAccount];
        
    }
}

void HRCryptoManagerUpdateSecurityQuestionsAndAnswers(NSArray *questions, NSArray *answers) {
    NSCAssert(questions, @"The questions must not be nil");
    NSCAssert(answers, @"The answers must not be nil");
    if (_temporaryKey) {
        
        // write  shared key
        NSData *keyData = [_temporaryKey dataUsingEncoding:NSUTF8StringEncoding];
        NSData *encryptedData = HRCryptoManagerEncrypt_private(keyData, [_temporaryAnswers componentsJoinedByString:@""]);
        [SSKeychain setPasswordData:encryptedData forService:HRKeychainService account:HRSharedKeySecurityAnswersKeychainAccount];
        
        // write clear questions
        NSData *questions = [NSJSONSerialization dataWithJSONObject:_temporaryQuestions options:0 error:nil];
        [SSKeychain setPasswordData:questions forService:HRKeychainService account:HRSecurityQuestionsKeychainAccount];
        
        // write hashed answers
        NSData *answers = [NSJSONSerialization dataWithJSONObject:_temporaryAnswers options:0 error:nil];
        answers = HRCryptoManagerHashData(answers);
        [SSKeychain setPasswordData:answers forService:HRKeychainService account:HRSecurityAnswersKeychainAccount];
        
    }
}

NSData * HRCryptoManagerKeychainItemData(NSString *service, NSString *account) {
    if (_temporaryKey) {
        NSData *value = [SSKeychain passwordDataForService:service account:account];
        return HRCryptoManagerDecrypt_private(value, _temporaryKey);
    }
    return nil;
}

NSString * HRCryptoManagerKeychainItemString(NSString *service, NSString *account) {
    NSData *value = HRCryptoManagerKeychainItemData(service, account);
    return [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
}

void HRCryptoManagerSetKeychainItemData(NSString *service, NSString *account, NSData *value) {
    if (_temporaryKey) {
        NSData *encrypted = HRCryptoManagerEncrypt_private(value, _temporaryKey);
        [SSKeychain setPasswordData:encrypted forService:service account:account];
    }
}

void HRCryptoManagerSetKeychainItemString(NSString *service, NSString *account, NSString *value) {
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    HRCryptoManagerSetKeychainItemData(service, account, valueData);
}

NSArray * HRCryptoManagerSecurityQuestions(void) {
    NSData *questions = [SSKeychain passwordDataForService:HRKeychainService account:HRSecurityQuestionsKeychainAccount];
    return [NSJSONSerialization JSONObjectWithData:questions options:0 error:nil];
}

@implementation HRCryptoManager

@end