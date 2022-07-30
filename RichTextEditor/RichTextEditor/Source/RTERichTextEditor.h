//
//  RichTextEditor.h
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

// TODO: better documentation
// TODO: Clean up, clean up, everybody do your share!

#import <Cocoa/Cocoa.h>

#import "RTETextFormat.h"

@class RichTextEditor;

// These values will always start from 0 and go up. If you want to add your own
// preview changes via a subclass, start from 9999 and go down (or similar) and
// override convertPreviewChangeTypeToString:withNonSpecialChangeText:
typedef NS_ENUM(NSInteger, RichTextEditorPreviewChange) {
    RichTextEditorPreviewChangeBold             = 0,
    RichTextEditorPreviewChangeItalic           = 1,
    RichTextEditorPreviewChangeUnderline        = 2,
    RichTextEditorPreviewChangeStrikethrough    = 3,
    RichTextEditorPreviewChangeFontResize       = 4,
    RichTextEditorPreviewChangeHighlight        = 5,
    RichTextEditorPreviewChangeFontSize         = 6,
    RichTextEditorPreviewChangeFontColor        = 7,
    RichTextEditorPreviewChangeIndentIncrease   = 8,
    RichTextEditorPreviewChangeIndentDecrease   = 9,
    RichTextEditorPreviewChangeCut              = 10,
    RichTextEditorPreviewChangePaste            = 11,
    RichTextEditorPreviewChangeSpace            = 12,
    RichTextEditorPreviewChangeEnter            = 13,
    RichTextEditorPreviewChangeBulletedList     = 14,
    RichTextEditorPreviewChangeOrderedList      = 15,
    RichTextEditorPreviewChangeHyperLink        = 16,
    RichTextEditorPreviewChangeMouseDown        = 17,
    RichTextEditorPreviewChangeMouseDragged     = 18,
    RichTextEditorPreviewChangeArrowKey         = 19,
    RichTextEditorPreviewChangeKeyDown          = 20,
    RichTextEditorPreviewChangeDelete           = 21,
    RichTextEditorPreviewChangeFindReplace      = 22
};

typedef NS_OPTIONS(NSUInteger, RichTextEditorShortcut) {
    RichTextEditorShortcutAll                   = 0,
    RichTextEditorShortcutBold                  = 1 << 0,
    RichTextEditorShortcutItalic                = 1 << 1,
    RichTextEditorShortcutUnderline             = 1 << 2,
    RichTextEditorShortcutStrikethrough         = 1 << 3,
    RichTextEditorShortcutIncreaseFontSize      = 1 << 4,
    RichTextEditorShortcutDecreaseFontSize      = 1 << 5,
    RichTextEditorShortcutBulletedList          = 1 << 6,
    RichTextEditorShortcutOrderedList           = 1 << 7,
    RichTextEditorShortcutLeaveBulletedList     = 1 << 8,
    RichTextEditorShortcutDecreaseIndent        = 1 << 9,
    RichTextEditorShortcutIncreaseIndent        = 1 << 10
};


@protocol RichTextEditorDataSource <NSObject>

@optional

- (NSUInteger)levelsOfUndo;

/// If you do not want to enable all keyboard shortcuts (e.g. if you don't want users to resize font ever),
/// then you can use this data source callback to selectively enable keyboard shortcuts.
- (RichTextEditorShortcut)enabledKeyboardShortcuts;

@end

@protocol RichTextEditorDelegate <NSObject>

@optional

- (void)richTextEditorBecomesFirstResponder:(RichTextEditor *_Nonnull)editor;
- (void)richTextEditorResignsFirstResponder:(RichTextEditor *_Nonnull)editor;
- (void)richTextEditor:(RichTextEditor *_Nonnull)editor changedSelectionTo:(NSRange)range withFormat:(RTETextFormat *_Nonnull)textFormat;
- (BOOL)richTextEditor:(RichTextEditor *_Nonnull)editor keyDownEvent:(NSEvent *_Nonnull)event; // return YES if handled by delegate, NO if RTE should process it
- (void)richTextEditor:(RichTextEditor *_Nonnull)editor changeAboutToOccurOfType:(RichTextEditorPreviewChange)type;

- (BOOL)richTextEditorHandlesUndoRedoForText:(RichTextEditor *_Nonnull)editor;
- (void)richTextEditorPerformedUndo:(RichTextEditor *_Nonnull)editor; // TODO: remove?
- (void)richTextEditorPerformedRedo:(RichTextEditor *_Nonnull)editor; // TODO: remove?

@end

@interface RichTextEditor : NSTextView

@property (assign) IBOutlet id<RichTextEditorDataSource> _Nullable rteDataSource;
@property (assign) IBOutlet id<RichTextEditorDelegate> _Nullable rteDelegate;

@property (nonatomic, strong, nullable) NSAttributedString *placeholderAttributedString;

@property (nonatomic, assign) CGFloat defaultIndentationSize;
@property (nonatomic, readonly) unichar lastSingleKeyPressed;

/// If YES, only pastes text as rich text if the copy operation came from this class.
/// Note: not this *object* -- this class (so other RichTextEditor boxes can paste
/// between each other). If the text did not come from a RichTextEditor box, then
/// pastes as plain text.
/// If NO, performs the default paste: operation.
/// Defaults to YES.
@property BOOL allowsRichTextPasteOnlyFromThisClass;

/// Amount to change font size on each increase/decrease font size call.
/// Defaults to 10.0f
@property CGFloat fontSizeChangeAmount;

/// Maximum font size. Defaults to 128.0f.
@property CGFloat maxFontSize;

/// Minimum font size. Defaults to 10.0f.
@property CGFloat minFontSize;

/// true if tab should always indent and shift+tab should always outdent the current paragraph(s);
/// false to let the tab key be used as normal
@property BOOL tabKeyAlwaysIndentsOutdents;

// MARK: -

+ (instancetype _Nonnull)initWithParent:(NSView *_Nonnull)parent frame:(NSRect)frame;
+ (instancetype _Nonnull)initWithParent:(NSView *_Nonnull)parent frame:(NSRect)frame widthTracks:(BOOL)widthTracks heightTracks:(BOOL)heightTracks;

// MARK: -

/// Pasteboard type string used when copying text from this NSTextView.
+ (NSString *_Nonnull)pasteboardDataType;

/// Call the following methods when the user does the given action (clicks bold button, etc.)

- (void)useSingleLineMode;

/// Toggle bold.
- (void)userSelectedBold;

/// Toggle italic.
- (void)userSelectedItalic;

/// Toggle underline.
- (void)userSelectedUnderline;

/// Toggle strikethrough.
- (void)userSelectedStrikethrough;

/// Toggle bulleted list.
- (void)userSelectedBullet;

/// Increase the total indentation of the current paragraph.
- (void)userSelectedIncreaseIndent;

/// Decrease the total indentation of the current paragraph.
- (void)userSelectedDecreaseIndent;

/// Change the text background (highlight) color for the currently selected text.
- (void)userSelectedTextBackgroundColor:(NSColor *_Nullable)color;

/// Change the text color for the currently selected text.
- (void)userSelectedTextColor:(NSColor *_Nullable)color;

/// Embedded hyperlink for for the currently selected text.
- (void)userApplyHyperlink:(NSURL *_Nullable)url;
- (void)userApplyHyperlink:(NSURL *_Nullable)url color:(NSColor *_Nullable)color;
- (void)userApplyHyperlink:(NSURL *_Nullable)url color:(NSColor *_Nullable)color underlineStyle:(NSUnderlineStyle)underlineStyle;

/// Perform an undo operation if one is available.
- (void)undo;

/// Perform a redo operation if one is available.
- (void)redo;

/// Convert the font for all text to the given font while keeping bold/italic attributes
- (void)changeFontTo:(NSFont *_Nonnull)font;

/// Change the currently selected text to the given font name.
- (void)userChangedToFontName:(NSString *_Nonnull)fontName;

/// Change the currently selected text to the specified font size.
- (void)userChangedToFontSize:(NSNumber *_Nonnull)fontSize;

/// Increases the font size of the currently selected text by self.fontSizeChangeAmount.
- (void)increaseFontSize;

/// Decreases the font size of the currently selected text by self.fontSizeChangeAmount.
- (void)decreaseFontSize;

/// Toggles whether or not the paragraphs in the currently selected text have a first
/// line head indent value of self.defaultIndentationSize.
- (void)userSelectedParagraphFirstLineHeadIndent;

/// Change the text alignment for the paragraphs in the currently selected text.
- (void)userSelectedTextAlignment:(NSTextAlignment)textAlignment;

/// Convenience method; YES if user has something selected (selection length > 0).
- (BOOL)hasSelection;

/// Changes the editor's lineFragmentPadding.
- (void)setLineFragmentPadding:(CGFloat)padding;

/// Changes the editor's maximumNumberOfLines.
- (void)setMaximumNumberOfLines:(CGFloat)numberOfLines;

/// Changes the editor's contents to the given attributed string.
- (void)setAttributedString:(NSAttributedString *_Nonnull)attributedString;

/// Convenience method to set the editor's border color.
- (void)setBorderColor:(NSColor *_Nonnull)borderColor;

/// Convenience method to set the editor's border width.
- (void)setBorderWidth:(CGFloat)borderWidth;

/// Check whether the current string is an HTML string.
+ (BOOL)isHTML:(NSString *_Nonnull)string;

/// Converts the current NSAttributedString to an HTML string.
- (NSString *_Nonnull)htmlString;

/// Converts the provided htmlString into an NSAttributedString and then
/// sets the editor's text to the attributed string.
- (void)setHtmlString:(NSString *_Nonnull)htmlString;

/// Grabs the NSString used as the bulleted list prefix.
- (NSString *_Nonnull)bulletString;

/// Converts the provided NSAttributedString into an HTML string.
+ (NSString *_Nonnull)htmlStringFromAttributedText:(NSAttributedString *_Nonnull)text;

/// Converts the given HTML string into an NSAttributedString.
+ (NSAttributedString *_Nullable)attributedStringFromHTMLString:(NSString *_Nonnull)htmlString;

/// Converts a given RichTextEditorPreviewChange to a human-readable string
+ (NSString *_Nonnull)convertPreviewChangeTypeToString:(RichTextEditorPreviewChange)changeType withNonSpecialChangeText:(BOOL)shouldReturnStringForNonSpecialType;

// // // // // // // // // // // // // // // // // // // //
// I'm not sure why you'd call these externally, but subclasses can make use of this for custom toolbar items or what have you.
// It's just easier to put these in the public header than to have a protected/subclasses-only header.
- (void)sendDelegatePreviewChangeOfType:(RichTextEditorPreviewChange)type;
- (void)sendDelegateTVChanged;

@end
