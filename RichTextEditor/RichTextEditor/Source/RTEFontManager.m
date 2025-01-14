//
//  RTEFontManager.m
//  RichTextEditor
//
//  Created by ChrisK on 7/5/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import "RTEFontManager.h"

@interface RTEFontManager () {
    NSMutableArray<NSFont *> *_availableFonts;
    NSMutableDictionary<NSString *, NSFont *> *_availableFontsDictionary;
}

@end

@implementation RTEFontManager

// MARK: -

+ (RTEFontManager *)sharedManager
{
    static RTEFontManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[RTEFontManager alloc] init];
    });
    
    return _sharedInstance;
}

// MARK: -

- (instancetype)init {
    if (self = [super init]) {
        _availableFonts = [[NSMutableArray alloc] init];
        _availableFontsDictionary = [[NSMutableDictionary alloc] init];
        
        NSFontCollection *collection = [NSFontCollection fontCollectionWithName:NSFontCollectionUser];
        NSArray<NSString *> *availableFontFamilies = [[NSFontManager sharedFontManager] availableFontFamilies];
        
        for (NSString *family in availableFontFamilies) {
            if ([collection matchingDescriptorsForFamily:family].count > 0) {
                NSFont *font = [NSFont fontWithName:family size:12];
                
                [_availableFonts addObject:font];
                [_availableFontsDictionary setObject:font forKey:family];
            }
        }
    }
    
    return self;
}

// MARK: -

- (NSArray<NSFont *> *)availableFonts {
    return _availableFonts;
}

- (NSDictionary<NSString *, NSFont *> *)availableFontsDictionary; {
    return _availableFontsDictionary;
}

// MARK: -

+ (void)startUp {
    [RTEFontManager sharedManager];
}

@end
