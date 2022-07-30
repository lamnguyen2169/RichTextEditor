//
//  RTELayoutManager.m
//  RichTextEditor
//
//  Created by ChrisK on 7/21/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import "RTELayoutManager.h"
#import "NSAttributedString+RichTextEditor.h"

@implementation RTELayoutManager

#pragma mark -

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin {
    [self updateFormatListLayout];
    [super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
}

#pragma mark -

- (void)updateFormatListLayout {
    NSTextStorage *textStorage = [self textStorage];
    NSTextContainer *textContainer = [[self textContainers] firstObject];
    CGFloat lineFragmentPadding = [textContainer lineFragmentPadding];
    
    if ((textStorage != nil) && (textContainer != nil)) {
        NSString *bulletString = [[self class] kBulletString];
        NSString *numberingString = [[self class] kNumberingString];
        __block NSInteger numbering = 0;
        __block NSInteger rangeOffset = 0;
        
        [textStorage enumarateParagraphsInRange:NSMakeRange(0, textStorage.length) withBlock:^(NSRange paragraphRange) {
            NSString *substring = [textStorage.string substringWithRange:paragraphRange];
            BOOL paragraphHasBullet = [substring hasPrefix:bulletString];
            BOOL paragraphHasNumbering = [substring hasPrefix:numberingString];
            
            if (paragraphHasNumbering) {
                numbering += 1;
            } else if (!paragraphHasBullet && !paragraphHasNumbering) {
                numbering = 0;
            }
            
            if (paragraphHasBullet || paragraphHasNumbering) {
                NSString *formatListString = paragraphHasBullet ? bulletString : numberingString;
                
                rangeOffset = rangeOffset + formatListString.length;
                
                NSDictionary *dictionary = [textStorage attributesAtIndex:MAX(paragraphRange.location + rangeOffset, 0)];
                NSRect paragraphRect = [self boundingRectForGlyphRange:paragraphRange inTextContainer:textContainer];
                CGSize indentationSize = [[[self class] indentationString] sizeWithAttributes:dictionary];
                NSRect usedRect = (paragraphRect.origin.x < indentationSize.width + lineFragmentPadding) ? NSMakeRect(indentationSize.width + lineFragmentPadding, paragraphRect.origin.y, paragraphRect.size.width, paragraphRect.size.height) : paragraphRect;
                
                NSFont *font = [dictionary objectForKey:NSFontAttributeName];
                NSColor *fontColor = [dictionary objectForKey:NSForegroundColorAttributeName];
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                [paragraphStyle setAlignment:NSTextAlignmentLeft];
                NSDictionary *attributes = @{NSFontAttributeName: font,
                                             NSForegroundColorAttributeName: fontColor,
                                             NSParagraphStyleAttributeName: paragraphStyle};
                NSMutableAttributedString *formatListAttributedString = [[NSMutableAttributedString alloc] initWithString:(paragraphHasBullet ? @"•" : [NSString stringWithFormat:@"%ld", numbering]) attributes:attributes];
                
                NSRect prefixRect = [formatListAttributedString boundingRectWithSize:NSMakeSize(FLT_MAX, FLT_MAX) options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) context:nil];
                CGFloat singleLineHeight = NSHeight([self boundingRectForGlyphRange:NSMakeRange(paragraphRange.location, formatListAttributedString.length) inTextContainer:textContainer]);
                NSPoint origin = NSMakePoint((NSMinX(usedRect) - NSWidth(prefixRect)) / 2, NSMinY(usedRect) + (NSHeight(usedRect) - NSHeight(prefixRect)) - (NSHeight(paragraphRect) - singleLineHeight));
                
                [formatListAttributedString drawWithRect:NSMakeRect(origin.x, origin.y, NSWidth(prefixRect), NSHeight(prefixRect)) options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) context:nil];
            }
        }];
    }
}

#pragma mark -

+ (NSString *)kBulletString {
    /// https://en.wikipedia.org/wiki/List_of_Unicode_characters
    /// \u00A0: Non-breaking space.
    /// Must add the Non-breaking space character after the control code.
    /// Otherwise, can't put mouse cursor at the first character of paragraph.
    return [NSString stringWithFormat:@"%C\u00A0", 0x010];
}

+ (NSString *)kNumberingString {
    /// https://en.wikipedia.org/wiki/List_of_Unicode_characters
    /// \u00A0: Non-breaking space.
    /// Must add the Non-breaking space character after the control code.
    /// Otherwise, can't put mouse cursor at the first character of paragraph.
    return [NSString stringWithFormat:@"%C\u00A0", 0x000];
}

+ (NSString *)indentationString {
    return @"\t\t";
}

@end
