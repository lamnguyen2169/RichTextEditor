//
//  RTEDefiniens.h
//  RichTextEditor
//
//  Created by lam1611 on 7/25/22.
//

#ifndef RTEDefiniens_h
#define RTEDefiniens_h

typedef NS_ENUM(NSInteger, ParagraphIndentation) {
    ParagraphIndentationIncrease,
    ParagraphIndentationDecrease
};

/// https://en.wikipedia.org/wiki/List_of_Unicode_characters
/// \u00A0: Non-breaking space.
static const NSString *kNonBreakingSpace = @"\u00A0";

static const CGFloat kBulletNumberingIndent = 15;
static const CGFloat kFirstLineHeadIndent = 52;

#endif /* RTEDefiniens_h */
