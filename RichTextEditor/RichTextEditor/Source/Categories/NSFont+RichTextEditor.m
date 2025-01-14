//
//  UIFont+RichTextEditor.m
//  RichTextEdtor
//
//  Created by Aryan Gh on 7/21/13.
//  Copyright (c) 2013 Aryan Ghassemi. All rights reserved.
//  Heavily modified for macOS by Deadpikle
//  Copyright (c) 2016 Deadpikle. All rights reserved.
//
// https://github.com/aryaxt/iOS-Rich-Text-Editor -- Original
// https://github.com/Deadpikle/macOS-Rich-Text-Editor -- Fork
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "NSFont+RichTextEditor.h"

@implementation NSFont (RichTextEditor)

+ (NSString *)postscriptNameFromFullName:(NSString *)fullName {
    // avoid error with "All system UI font access should be through proper APIs..."
    // by bailing early if the user gets here with a system font
    if ([fullName containsString:@"SFNS"]) {
        return fullName;
    }
    NSFont *font = [NSFont fontWithName:fullName size:1];
    return (__bridge NSString *)(CTFontCopyPostScriptName((__bridge CTFontRef)(font)));
}

+ (NSFont *)fontWithName:(NSString *)name size:(CGFloat)size boldTrait:(BOOL)isBold italicTrait:(BOOL)isItalic {
    // avoid error with "All system UI font access should be through proper APIs..."
    // by bailing early if the user gets here with a system font
    if ([name containsString:@"SFNS"]) {
        NSFontManager *fontManager = [NSFontManager sharedFontManager];
        NSFont *sysFont = [NSFont systemFontOfSize:size];
        if (isItalic) {
            sysFont = [fontManager convertFont:sysFont toHaveTrait:NSFontItalicTrait];
        }
        if (isBold) {
            sysFont = [fontManager convertFont:sysFont toHaveTrait:NSFontBoldTrait];
        }
        return sysFont;
    }
    
    NSString *postScriptName = [NSFont postscriptNameFromFullName:name];
    CTFontRef fontWithoutTrait = CTFontCreateWithName((__bridge CFStringRef)(postScriptName), size, NULL);
    CTFontSymbolicTraits traits = 0;
    CTFontRef newFontRef;
    
    if (isItalic) {
        traits |= kCTFontItalicTrait;
    }
    
    if (isBold) {
        traits |= kCTFontBoldTrait;
    }
    
    if (traits == 0) {
        newFontRef = CTFontCreateCopyWithAttributes(fontWithoutTrait, 0.0, NULL, NULL);
    } else {
        newFontRef = CTFontCreateCopyWithSymbolicTraits(fontWithoutTrait, 0.0, NULL, traits, traits);
        
        if (newFontRef == NULL) {
            newFontRef = CTFontCreateCopyWithAttributes(fontWithoutTrait, 0.0, NULL, NULL);
        }
    }
    
    if (fontWithoutTrait) {
        CFRelease(fontWithoutTrait);
    }
    
    if (newFontRef) {
        NSString *fontNameKey = (__bridge NSString *)(CTFontCopyName(newFontRef, kCTFontPostScriptNameKey));
        CGFloat size = CTFontGetSize(newFontRef);
        CFRelease(newFontRef);
        return [NSFont fontWithName:fontNameKey size:size];
    }
    
    return nil;
}

- (NSFont *)fontWithBoldTrait:(BOOL)bold italicTrait:(BOOL)italic andSize:(CGFloat)size {
    CTFontRef fontRef = (__bridge CTFontRef)self;
    NSString *familyName = (__bridge NSString *)(CTFontCopyName(fontRef, kCTFontFamilyNameKey));
    NSString *postScriptName = [NSFont postscriptNameFromFullName:familyName];
    return [[self class] fontWithName:postScriptName size:size boldTrait:bold italicTrait:italic];
}

- (NSFont *)fontWithBoldTrait:(BOOL)bold andItalicTrait:(BOOL)italic {
    return [self fontWithBoldTrait:bold italicTrait:italic andSize:self.pointSize];
}

- (BOOL)isBold {
    CTFontSymbolicTraits trait = CTFontGetSymbolicTraits((__bridge CTFontRef)self);
    if ((trait & kCTFontTraitBold) == kCTFontTraitBold) {
        return YES;
    }
    
    return NO;
}

- (BOOL)isItalic {
    CTFontSymbolicTraits trait = CTFontGetSymbolicTraits((__bridge CTFontRef)self);
    if ((trait & kCTFontTraitItalic) == kCTFontTraitItalic) {
        return YES;
    }
    
    return NO;
}

@end
