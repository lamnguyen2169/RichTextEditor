//
//  RTETextFormat.h
//  Presenter
//
//  Created by lam1611 on 7/8/22.
//  Copyright © 2022 Personify. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RTETextFormat : NSObject

@property (nonatomic, strong, nullable) NSFont *font;
@property (nonatomic, assign) BOOL isBold;
@property (nonatomic, assign) BOOL isItalic;
@property (nonatomic, assign) BOOL isUnderline;
@property (nonatomic, assign) BOOL isStrikethrough;
@property (nonatomic, assign) BOOL isBulletedList;
@property (nonatomic, assign) BOOL isOrderedList;
@property (nonatomic, assign) BOOL hyperlinkEnabled;
@property (nonatomic, assign) NSTextAlignment textAlignment;
@property (nonatomic, strong, nullable) NSURL *hyperlink;
@property (nonatomic, strong, nullable) NSColor *textColor;
@property (nonatomic, strong, nullable) NSColor *textBackgroundColor;

@end
