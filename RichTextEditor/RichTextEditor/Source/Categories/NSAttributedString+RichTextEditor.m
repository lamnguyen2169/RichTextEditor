//
//  NSAttributedString+RichTextEditor.m
//  RichTextEdtor
//
//  Created by Aryan Gh on 7/21/13.
//  Copyright (c) 2013 Aryan Ghassemi. All rights reserved.
//  Heavily modified for macOS by Deadpikle
//  Copyright (c) 2016 Deadpikle. All rights reserved.
//  Modified for macOS by ChrisK
//  Copyright (c) 2022 ChrisK. All rights reserved.
//
// https://github.com/aryaxt/iOS-Rich-Text-Editor -- Original
// https://github.com/Deadpikle/macOS-Rich-Text-Editor -- Fork
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

#import "NSAttributedString+RichTextEditor.h"

#import "NSFont+RichTextEditor.h"
#import "RTEFontManager.h"

@implementation NSAttributedString (RichTextEditor)

- (nullable instancetype)initWithData:(NSData *_Nonnull)data options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> *_Nonnull)options documentAttributes:(NSDictionary<NSAttributedStringDocumentAttributeKey, id> * _Nullable * _Nullable)documentAttributes error:(NSError *__autoreleasing _Nullable * _Nullable)error defaultAttributes:(NSDictionary<NSAttributedStringKey, id> *_Nonnull)defaultAttributes {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithData:data
                                                                                          options:options
                                                                               documentAttributes:documentAttributes
                                                                                            error:error];
    
    if (attributedString.length > 0) {
        /// Set default color to the attributed string after parsing from HTML string, in case of no available color found.
        NSColor *foregroundColor = [defaultAttributes objectForKey:NSForegroundColorAttributeName];
        
        if ([foregroundColor isKindOfClass:[NSColor class]]) {
            [attributedString beginEditing];
            [attributedString enumerateAttribute:NSForegroundColorAttributeName inRange:NSMakeRange(0, attributedString.length) options:kNilOptions usingBlock:^(id _Nullable value, NSRange range, BOOL * _Nonnull stop) {
                /// Set default color to the attributed string after parsing from HTML string, in case of no available color found.
                if (![value isKindOfClass:[NSColor class]]) {
                    [attributedString addAttribute:NSForegroundColorAttributeName value:foregroundColor range:range];
                }
            }];
            [attributedString endEditing];
        }
        
        /// Set default font to the attributed string after parsing from HTML string, in case of no available font found.
        NSFont *defaultFont = [defaultAttributes objectForKey:NSFontAttributeName];
        
        if ([defaultFont isKindOfClass:[NSFont class]]) {
            NSDictionary<NSString *, NSFont *> *availableFonts = [[RTEFontManager sharedManager] availableFontsDictionary];
            
            [attributedString beginEditing];
            [attributedString enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, attributedString.length) options:kNilOptions usingBlock:^(id _Nullable value, NSRange range, BOOL * _Nonnull stop) {
                if ([value isKindOfClass:[NSFont class]]) {
                    NSFont *font = (NSFont *)value;
                    BOOL fontNotFound = (font.familyName == nil) || ((font.familyName != nil) && ([availableFonts objectForKey:font.familyName] == nil));
                    
                    /// Set default font to the attributed string after parsing from HTML string, in case of no available font found.
                    if (fontNotFound) {
                        BOOL isBold = [font isBold];
                        BOOL isItalic = [font isItalic];
                        NSFont *replacingFont = [NSFont fontWithName:defaultFont.fontName size:font.pointSize boldTrait:isBold italicTrait:isItalic];
                        
                        if (replacingFont == nil) {
                            replacingFont = [defaultFont fontWithBoldTrait:isBold italicTrait:isItalic andSize:font.pointSize];
                        }
                        
                        if (replacingFont != nil) {
                            [attributedString removeAttribute:NSFontAttributeName range:range];
                            [attributedString addAttribute:NSFontAttributeName value:replacingFont range:range];
                        } else {
                            NSLog(@"%s [Line %d] availableFonts NOT contains, cannot replace font: %@", __PRETTY_FUNCTION__, __LINE__, font);
                        }
                    }
                }
            }];
            [attributedString endEditing];
        }
        
        return attributedString;
    }
    
    return nil;
}

#pragma mark - Public Methods -

- (NSRange)firstParagraphRangeFromTextRange:(NSRange)range {
    if (self.string.length == 0 || self.string.length < range.location) {
        return NSMakeRange(0, 0);
    }
    
    NSInteger start = -1;
    NSInteger end = -1;
    NSInteger length = 0;
    
    NSInteger startingRange = (range.location == self.string.length || [self.string characterAtIndex:range.location] == '\n') ?
    range.location-1 :
    range.location;
    
    for (NSInteger i = startingRange; i >= 0; i--) {
        char c = [self.string characterAtIndex:i];
        if (c == '\n') {
            start = i+1;
            break;
        }
    }
    
    start = (start == -1) ? 0 : start;
    
    NSInteger moveForwardIndex = (range.location > start) ? range.location : start;
    
    for (NSInteger i = moveForwardIndex; i <= self.string.length - 1; i++) {
        char c = [self.string characterAtIndex:i];
        if (c == '\n')
        {
            end = i;
            break;
        }
    }
    
    end = (end == -1) ? self.string.length : end;
    length = end - start;
    
    return NSMakeRange(start, length);
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location {
    if ((self.string.length == 0) || (location >= self.string.length)) {
        return @{}; // end of string, use whatever we're currently using
    } else {
        return [self attributesAtIndex:location effectiveRange:nil];
    }
}

- (NSArray *)rangeOfParagraphsFromTextRange:(NSRange)textRange {
    NSMutableArray *paragraphRanges = [NSMutableArray array];
    NSInteger rangeStartIndex = textRange.location;
    
    while (true) {
        NSRange range = [self firstParagraphRangeFromTextRange:NSMakeRange(rangeStartIndex, 0)];
        rangeStartIndex = range.location + range.length + 1;
        
        [paragraphRanges addObject:[NSValue valueWithRange:range]];
        
        if (range.location + range.length >= textRange.location + textRange.length) {
            break;
        }
    }
    
    return paragraphRanges;
}

- (void)enumarateParagraphsInRange:(NSRange)range withBlock:(void (^)(NSRange paragraphRange))block {
    NSArray *rangeOfParagraphsInSelectedText = [self rangeOfParagraphsFromTextRange:range];
    
    for (int i = 0; i < rangeOfParagraphsInSelectedText.count; i++) {
        NSValue *value = rangeOfParagraphsInSelectedText[i];
        NSRange paragraphRange = [value rangeValue];
        block(paragraphRange);
    }
}

- (NSString *)htmlString {
    NSMutableString *htmlString = [NSMutableString string];
    NSArray *paragraphRanges = [self rangeOfParagraphsFromTextRange:NSMakeRange(0, self.string.length - 1)];
    
    for (int i = 0; i < paragraphRanges.count; i++) {
        NSValue *value = paragraphRanges[i];
        NSRange range = [value rangeValue];
        NSDictionary *paragraphDictionary = [self attributesAtIndex:range.location effectiveRange:nil];
        NSParagraphStyle *paragraphStyle = [paragraphDictionary objectForKey:NSParagraphStyleAttributeName];
        NSString *textAlignmentString = [self htmlTextAlignmentString:paragraphStyle.alignment];
        
        [htmlString appendString:@"<p "];
        
        if (textAlignmentString) {
            [htmlString appendFormat:@"align=\"%@\" ", textAlignmentString];
        }
        
        [htmlString appendFormat:@"style=\""];
        
        if (paragraphStyle.firstLineHeadIndent > 0) {
            [htmlString appendFormat:@"text-indent:%.0fpx; ", paragraphStyle.firstLineHeadIndent - paragraphStyle.headIndent];
        }
        
        if (paragraphStyle.headIndent > 0) {
            [htmlString appendFormat:@"margin-left:%.0fpx; ", paragraphStyle.headIndent];
        }
        
        
        [htmlString appendString:@" \">"];
        
        [self enumerateAttributesInRange:range
                                 options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                              usingBlock:^(NSDictionary *dictionary, NSRange range, BOOL *stop){
            
            NSMutableString *fontString = [NSMutableString string];
            NSFont *font = [dictionary objectForKey:NSFontAttributeName];
            NSColor *foregroundColor = [dictionary objectForKey:NSForegroundColorAttributeName];
            NSColor *backGroundColor = [dictionary objectForKey:NSBackgroundColorAttributeName];
            NSNumber *underline = [dictionary objectForKey:NSUnderlineStyleAttributeName];
            BOOL hasUnderline = (!underline || underline.intValue == NSUnderlineStyleNone) ? NO : YES;
            NSNumber *strikeThrough = [dictionary objectForKey:NSStrikethroughStyleAttributeName];
            BOOL hasStrikeThrough = (!strikeThrough || strikeThrough.intValue == NSUnderlineStyleNone) ? NO : YES;
            
            [fontString appendFormat:@"<font "];
            [fontString appendFormat:@"face=\"%@\" ", font.familyName];
            
            // Begin style
            [fontString appendString:@" style=\" "];
            
            [fontString appendFormat:@"font-size:%.0fpx; ", font.pointSize];
            
            if (foregroundColor && [foregroundColor isKindOfClass:[NSColor class]]) {
                [fontString appendFormat:@"color:%@; ", [self htmlRgbColor:foregroundColor]];
            }
            
            if (backGroundColor && [backGroundColor isKindOfClass:[NSColor class]]) {
                [fontString appendFormat:@"background-color:%@; ", [self htmlRgbColor:backGroundColor]];
            }
            
            [fontString appendString:@"\" "];
            // End Style
            
            [fontString appendString:@">"];
            [fontString appendString:[[self.string substringFromIndex:range.location] substringToIndex:range.length]];
            [fontString appendString:@"</font>"];
            if ([font isBold]) {
                [fontString insertString:@"<b>" atIndex:0];
                [fontString insertString:@"</b>" atIndex:fontString.length];
            }
            
            if ([font isItalic]) {
                [fontString insertString:@"<i>" atIndex:0];
                [fontString insertString:@"</i>" atIndex:fontString.length];
            }
            
            if (hasUnderline) {
                [fontString insertString:@"<u>" atIndex:0];
                [fontString insertString:@"</u>" atIndex:fontString.length];
            }
            
            if (hasStrikeThrough) {
                [fontString insertString:@"<strike>" atIndex:0];
                [fontString insertString:@"</strike>" atIndex:fontString.length];
            }
            
            [htmlString appendString:fontString];
        }];
        [htmlString appendString:@"</p>"];
    }
    
    return htmlString;
}

- (NSURL *)hyperlinkFromTextRange:(NSRange)textRange {
    if (textRange.length > 0) {
        NSDictionary *dictionary = [self attributesAtIndex:textRange.location];
        id link = [dictionary objectForKey:NSLinkAttributeName];
        
        if ([link isKindOfClass:[NSURL class]]) {
            return (NSURL *)link;
        } else if ([link isKindOfClass:[NSString class]]) {
            NSURL *url = [[NSURL alloc] initWithString:(NSString *)link];
            
            return url;
        }
    }
    
    return nil;
}

#pragma mark - Helper Methods -

- (NSString *)htmlTextAlignmentString:(NSTextAlignment)textAlignment {
    switch (textAlignment) {
        case NSTextAlignmentLeft:
            return @"left";
        case NSTextAlignmentCenter:
            return @"center";
        case NSTextAlignmentRight:
            return @"right";
        case NSTextAlignmentJustified:
            return @"justify";
        default:
            return nil;
    }
}

- (NSString *)htmlRgbColor:(NSColor *)color {
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    return [NSString stringWithFormat:@"rgb(%d,%d,%d)",(int)(red * 255.0), (int)(green * 255.0), (int)(blue * 255.0)];
}

@end
