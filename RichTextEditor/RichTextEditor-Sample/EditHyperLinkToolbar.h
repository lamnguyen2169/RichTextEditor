//
//  EditHyperLinkToolbar.h
//  macOSRTESample
//
//  Created by lam1611 on 7/5/22.
//  Copyright © 2022 Pikle Productions. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol EditToolbarDelegate <NSObject>

@optional
- (void)toolbarDidChangeFormatLink:(NSURL *_Nullable)link;

@end

NS_ASSUME_NONNULL_BEGIN

@interface EditHyperLinkToolbar : NSViewController

@property (nonatomic, weak, nullable) id<EditToolbarDelegate> delegate;

@property (nonatomic, strong, nullable) NSURL *hyperlink;

@end

NS_ASSUME_NONNULL_END
