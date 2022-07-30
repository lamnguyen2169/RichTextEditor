//
//  NSString+Extensions.h
//  macOSRTESample
//
//  Created by lam1611 on 7/5/22.
//  Copyright © 2022 Pikle Productions. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Extensions)

- (void)validateURL:(void (^)(bool isValid))complete;

@end

NS_ASSUME_NONNULL_END
