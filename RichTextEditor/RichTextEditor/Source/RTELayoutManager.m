//
//  RTELayoutManager.m
//  RichTextEditor
//
//  Created by ChrisK on 7/21/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import "RTELayoutManager.h"

#import "RTEDefiniens.h"
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
    NSColor *bulletNumberingColor = self.bulletNumberingColor;
    CGFloat bulletNumberingIndent = self.bulletNumberingIndent;
    CGFloat firstLineHeadIndent = self.firstLineHeadIndent;
    
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
                
                NSDictionary *dictionary = [textStorage attributesAtIndex:MAX(paragraphRange.location + ((paragraphRange.length > formatListString.length) ? rangeOffset : 0), 0)];
                
                if ([dictionary objectForKey:NSFontAttributeName] == nil) {
                    dictionary = [textStorage attributesAtIndex:MAX(paragraphRange.location, 0)];
                }
                
                NSRect paragraphRect = [self boundingRectForGlyphRange:paragraphRange inTextContainer:textContainer];
                NSRect usedRect = (paragraphRect.origin.x < firstLineHeadIndent + lineFragmentPadding) ? NSMakeRect(firstLineHeadIndent + lineFragmentPadding, paragraphRect.origin.y, paragraphRect.size.width, paragraphRect.size.height) : paragraphRect;
                
                NSFont *font = [dictionary objectForKey:NSFontAttributeName];
                NSFont *bulletFont = [NSFont fontWithName:font.familyName size:font.pointSize];
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                [paragraphStyle setAlignment:NSTextAlignmentLeft];
                NSDictionary *attributes = @{NSFontAttributeName: (bulletFont != nil) ? bulletFont : font,
                                             NSForegroundColorAttributeName: bulletNumberingColor,
                                             NSParagraphStyleAttributeName: paragraphStyle};
                NSMutableAttributedString *formatListAttributedString = [[NSMutableAttributedString alloc] initWithString:(paragraphHasBullet ? @"•" : [NSString stringWithFormat:@"%ld", numbering]) attributes:attributes];
                
                NSRect boundingRect = [formatListAttributedString boundingRectWithSize:NSMakeSize(FLT_MAX, FLT_MAX) options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) context:nil];
                CGFloat singleLineHeight = NSHeight([self boundingRectForGlyphRange:NSMakeRange(paragraphRange.location, formatListAttributedString.length) inTextContainer:textContainer]);
                NSPoint origin = NSMakePoint(bulletNumberingIndent, NSMinY(usedRect) + (NSHeight(usedRect) - NSHeight(boundingRect)) - (NSHeight(paragraphRect) - singleLineHeight));
                NSRect drawRect = NSMakeRect(origin.x, origin.y, NSWidth(boundingRect), NSHeight(boundingRect));
                
                [formatListAttributedString drawWithRect:drawRect options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) context:nil];
                
                /// Update the paragraphStyle's firstLineHeadIndent in case of drawing rect of bullets or numberings
                /// exceeds the firstLineHeadIndent value
                {
                    CGSize expectedStringSize = [formatListString sizeWithAttributes:dictionary];
                    CGFloat lineHeadIndent = (NSMaxX(drawRect) > firstLineHeadIndent) ? (NSMaxX(drawRect) + expectedStringSize.width) : firstLineHeadIndent;
                    NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
                    
                    if (!paragraphStyle) {
                        paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                    }
                    
                    if (lineHeadIndent != paragraphStyle.firstLineHeadIndent) {
                        paragraphStyle.firstLineHeadIndent = lineHeadIndent;
                        
                        [textStorage addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:paragraphRange];
                    }
                }
            }
        }];
    }
}

#pragma mark -

+ (NSString *)kBulletString {
    /// Must add the Non-breaking space character after the control code.
    /// Otherwise, can't put mouse cursor at the first character of paragraph.
    return [NSString stringWithFormat:@"%C%@", 0x010, kNonBreakingSpace];
}

+ (NSString *)kNumberingString {
    /// Must add the Non-breaking space character after the control code.
    /// Otherwise, can't put mouse cursor at the first character of paragraph.
    return [NSString stringWithFormat:@"%C%@", 0x011, kNonBreakingSpace];
}

+ (NSString *)kEncodedBulletString {
    NSString *string = [NSString stringWithFormat:@"%C", 0x010];
    NSData *data = [string dataUsingEncoding:NSNonLossyASCIIStringEncoding];
    NSString *encodedString = [NSString stringWithFormat:@"%@%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], kNonBreakingSpace];
    
    return encodedString;
}

+ (NSString *)kEncodedNumberingString {
    NSString *string = [NSString stringWithFormat:@"%C", 0x000];
    NSData *data = [string dataUsingEncoding:NSNonLossyASCIIStringEncoding];
    NSString *encodedString = [NSString stringWithFormat:@"%@%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], kNonBreakingSpace];
    
    return encodedString;
}

@end

@implementation NSLayoutManager (RichTextEditor)

- (RTELayoutManager *)RTEInstance {
    if ([self isKindOfClass:[RTELayoutManager class]]) {
        return (RTELayoutManager *)self;
    }
    
    return nil;
}

@end
