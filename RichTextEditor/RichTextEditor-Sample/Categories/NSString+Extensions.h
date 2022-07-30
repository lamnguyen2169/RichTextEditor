//
//  NSString+Extensions.h
//  macOSRTESample
//
//  Created by ChrisK on 7/5/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Extensions)

- (void)validateURL:(void (^)(bool isValid))complete;

@end

NS_ASSUME_NONNULL_END
