//
//  NSString+Extensions.m
//  RichTextEditor-Sample
//
//  Created by ChrisK on 7/5/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import "NSString+Extensions.h"

@implementation NSString (Extensions)

- (void)validateURL:(void (^)(bool isValid))complete {
    NSString *urlString = self;
    NSError *error;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    
    if (!error && detector) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSRange match = [detector rangeOfFirstMatchInString:urlString options:kNilOptions range:NSMakeRange(0, urlString.length)];
        
        if ((match.length == urlString.length) && (url.host.length > 0)) {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
            [request setHTTPMethod:@"HEAD"];
            
            NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                if (!error && [response isKindOfClass:[NSHTTPURLResponse class]] && (((NSHTTPURLResponse *)response).statusCode == 200)) {
                    complete(YES);
                } else {
                    complete(NO);
                }
            }];
            
            [task resume];
        } else {
            complete(NO);
        }
    } else {
        complete(NO);
    }
}

@end
