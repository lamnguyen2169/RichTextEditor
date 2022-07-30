//
//  RichTextEditor.h
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

// Text editing architecture guide: https://developer.apple.com/library/mac/documentation/TextFonts/Conceptual/CocoaTextArchitecture/TextEditing/TextEditing.html#//apple_ref/doc/uid/TP40009459-CH3-SW1

#import <QuartzCore/QuartzCore.h>
#import  <objc/runtime.h>

#import "RTERichTextEditor.h"

#import "RTEDefiniens.h"
#import "RTETextFormat.h"
#import "RTELayoutManager.h"
#import "NSFont+RichTextEditor.h"
#import "NSAttributedString+RichTextEditor.h"
#import "WZProtocolInterceptor.h"

@interface RichTextEditor () <NSTextViewDelegate> {
}

/// Gets set to YES when the user starts changing attributes when there is no text selection (selecting bold, italic, etc)
/// Gets set to NO  when the user changes selection or starts typing
@property (nonatomic, assign) BOOL typingAttributesInProgress;

@property (nonatomic, assign) float currSysVersion;

@property (nonatomic, assign) NSInteger MAX_INDENT;
@property (nonatomic, assign) BOOL isInTextDidChange;

@property (nonatomic, assign) NSUInteger levelsOfUndo;
@property (nonatomic, assign) NSUInteger previousCursorPosition;

@property (nonatomic, strong) NSColor *bulletNumberingColor;
@property (nonatomic, assign) CGFloat bulletNumberingIndent;
@property (nonatomic, assign) CGFloat firstLineHeadIndent;
@property (nonatomic, assign) BOOL inBulletedList;
@property (nonatomic, assign) BOOL inNumberedList;
@property (nonatomic, assign) BOOL justDeletedBackward;
@property (nonatomic, strong) NSString *latestReplacementString;
@property (nonatomic, strong) NSString *latestStringReplaced;

@property (nonatomic, assign) NSRange lastAnchorPoint;
@property (nonatomic, assign) BOOL shouldEndColorChangeOnLeft;
@property (nonatomic, assign) BOOL usesSingleLineMode;

@property WZProtocolInterceptor *delegate_interceptor;

@end

@implementation RichTextEditor

+ (NSString *)pasteboardDataType {
    return @"RTERichTextEditor";
}

#pragma mark - Initialization -

- (instancetype)init {
    if (self = [super init]) {
        [self commonInitialization];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInitialization];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInitialization];
    }
    
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)container {
    if (self = [super initWithFrame:frameRect textContainer:container]) {
        [self commonInitialization];
    }
    
    return self;
}

+ (instancetype)initWithParent:(NSView *)parent frame:(NSRect)frame {
    NSSize contentSize = frame.size;
    
    ///
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:frame];
    [scrollView setDrawsBackground:NO];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setHasVerticalScroller:NO];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setVerticalScrollElasticity:NSScrollElasticityAllowed];
    [scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
    [scrollView setContentInsets:NSEdgeInsetsZero];
    [scrollView setScrollerInsets:NSEdgeInsetsMake(0, 0, -NSHeight([scrollView.horizontalScroller frame]), -NSHeight([scrollView.verticalScroller frame]))];
    [scrollView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    [parent addSubview:scrollView];
    
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:NSMakeSize(contentSize.width, FLT_MAX)];
    RTELayoutManager *layoutManager = [[RTELayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    [textStorage addLayoutManager:layoutManager];
    
    RichTextEditor *textEditor = [[RichTextEditor alloc] initWithFrame:frame textContainer:textContainer];
    [textEditor setTextColor:[NSColor blackColor]];
    [textEditor setAllowsUndo:YES];
    [textEditor setEditable:YES];
    [textEditor setSelectable:YES];
    [textEditor setBackgroundColor:[NSColor clearColor]];
    [textEditor setAlignment:NSTextAlignmentLeft];
    [textEditor setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [textEditor setHorizontallyResizable:NO];
    [textEditor setVerticallyResizable:YES];
    [textEditor setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [textEditor setTextContainerInset:NSZeroSize];
    [[textEditor textContainer] setWidthTracksTextView:NO];
    [[textEditor textContainer] setHeightTracksTextView:NO];
    [[textEditor textContainer] setMaximumNumberOfLines:0];
    
    [scrollView setDocumentView:textEditor];
    [scrollView setAutoresizesSubviews:YES];
    
    return textEditor;
}

#pragma mark -

- (BOOL)acceptsFirstResponder {
    return [self isEditable];
}

- (BOOL)becomeFirstResponder {
    BOOL isFirstResponder = [super becomeFirstResponder];
    
    if (self.rteDelegate && [self.rteDelegate respondsToSelector:@selector(richTextEditorBecomesFirstResponder:withFormat:)]) {
        RTETextFormat *textFormat = [self typingTextFormat];
        
        [self.rteDelegate richTextEditorBecomesFirstResponder:self withFormat:textFormat];
    }
    
    return isFirstResponder;
}

- (BOOL)resignFirstResponder {
    BOOL isResigned = [super resignFirstResponder];
    
    if (self.rteDelegate && [self.rteDelegate respondsToSelector:@selector(richTextEditorResignsFirstResponder:)]) {
        [self.rteDelegate richTextEditorResignsFirstResponder:self];
    }
    
    return isResigned;
}

- (void)setFrame:(NSRect)frame {
    NSView *parent = [self superview];
    NSRect parentFrame = [parent bounds];
    NSRect dirtyRect = frame;
    
    if ([parent isKindOfClass:[NSClipView class]] && !NSEqualRects(parentFrame, frame)) {
        if (self.usesSingleLineMode) {
            dirtyRect = NSMakeRect(NSMinX(frame), NSMinY(frame), NSWidth(frame), NSHeight(parentFrame));
            [[self textContainer] setContainerSize:NSMakeSize(FLT_MAX, NSHeight(frame))];
        } else {
            dirtyRect = NSMakeRect(NSMinX(frame), NSMinY(frame), NSWidth(parentFrame), NSHeight(frame));
            [[self textContainer] setContainerSize:NSMakeSize(NSWidth(parentFrame), FLT_MAX)];
        }
    }
    
    [super setFrame:dirtyRect];
}

- (void)setPlaceholderAttributedString:(NSAttributedString *)placeholderAttributedString {
    _placeholderAttributedString = placeholderAttributedString;
    
    [self setNeedsUpdateLayout:YES];
}

- (id)delegate {
    return self.delegate_interceptor;
}

- (void)setDelegate:(id)newDelegate {
    [super setDelegate:nil];
    self.delegate_interceptor.receiver = newDelegate;
    [super setDelegate:(id)self.delegate_interceptor];
}

#pragma mark -

- (void)commonInitialization {
    /// Prevent the use of self.delegate = self
    /// http://stackoverflow.com/questions/3498158/intercept-objective-c-delegate-messages-within-a-subclass
    Protocol *protocol = objc_getProtocol("NSTextViewDelegate");
    self.delegate_interceptor = [[WZProtocolInterceptor alloc] initWithInterceptedProtocol:protocol];
    [self.delegate_interceptor setMiddleMan:self];
    [super setDelegate:(id)self.delegate_interceptor];
    self.allowsRichTextPasteOnlyFromThisClass = YES;
    
    self.borderColor = [NSColor lightGrayColor];
    self.borderWidth = 1.0;
    
    self.shouldEndColorChangeOnLeft = NO;
    
    self.typingAttributesInProgress = NO;
    self.isInTextDidChange = NO;
    self.fontSizeChangeAmount = 6.0f;
    self.maxFontSize = 128.0f;
    self.minFontSize = 10.0f;
    self.levelsOfUndo = 10;
    
    self.latestReplacementString = @"";
    self.latestStringReplaced = @"";
    
    /// Instead of hard-coding the default indentation size, which can make bulleted lists look a little
    /// odd when increasing/decreasing their indent, use double \t characters width instead
    /// The old firstLineHeadIndent was 15
    /// TODO: readjust this firstLineHeadIndent when font size changes? Might make things weird.
    self.bulletNumberingColor = [NSColor colorWithSRGBRed:(28.0 / 255) green:(41.0 / 255) blue:(51.0 / 255) alpha:1.0];
    self.bulletNumberingIndent = kBulletNumberingIndent;
    self.firstLineHeadIndent = kFirstLineHeadIndent;
    self.MAX_INDENT = self.firstLineHeadIndent * 10;
    
    if (self.rteDataSource && [self.rteDataSource respondsToSelector:@selector(levelsOfUndo)]) {
        [[self undoManager] setLevelsOfUndo:[self.rteDataSource levelsOfUndo]];
    } else {
        [[self undoManager] setLevelsOfUndo:self.levelsOfUndo];
    }
    
    /// http://stackoverflow.com/questions/26454037/uitextview-text-selection-and-highlight-jumping-in-ios-8
    [[self layoutManager] setAllowsNonContiguousLayout:NO];
    [self setSelectedRange:NSMakeRange(0, 0)];
    [self setBulletNumberingColor:self.bulletNumberingColor];
    [self setBulletNumberingIndent:self.bulletNumberingIndent];
    [self setFirstLineHeadIndent:self.firstLineHeadIndent];
    
    if ([[self.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@""]) {
        [[self textStorage] setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
    }
}

- (BOOL)rangeExists:(NSRange)range {
    return (range.location != NSNotFound) && ((range.location + range.length) <= self.attributedString.length);
}

#pragma mark - NSTextViewDelegate

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    self.latestReplacementString = replacementString;
    
    if (affectedCharRange.length > 0 && [self rangeExists:affectedCharRange]) {
        self.latestStringReplaced = [self.string substringWithRange:affectedCharRange];
    } else {
        self.latestStringReplaced = @"";
    }
    
    if ([replacementString isEqualToString:@"\n"]) {
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeEnter];
        self.inBulletedList = [self isInBulletedList];
        self.inNumberedList = [self isInNumberedList];
    }
    if ([replacementString isEqualToString:@" "]) {
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeSpace];
    }
    if (self.delegate_interceptor.receiver && [self.delegate_interceptor.receiver respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementString:)]) {
        return [self.delegate_interceptor.receiver textView:textView shouldChangeTextInRange:affectedCharRange replacementString:replacementString];
    }
    if (self.tabKeyAlwaysIndentsOutdents && [replacementString isEqualToString:@"\t"] && affectedCharRange.length == 0) {
        // [self userSelectedIncreaseIndent];
        // return NO;
    }
    
    return YES;
}

// http://stackoverflow.com/questions/2484072/how-can-i-make-the-tab-key-move-focus-out-of-a-nstextview
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector {
    if (self.delegate_interceptor.receiver && [self.delegate_interceptor.receiver respondsToSelector:@selector(textView:doCommandBySelector:)]) {
        return [self.delegate_interceptor.receiver textView:aTextView doCommandBySelector:aSelector];
    }
    
    if (aSelector == @selector(insertTab:)) {
        if ([self isInEmptyBulletedListItem] && [self isInEmptyNumberedListItem]) {
            [self userSelectedIncreaseIndent];
            return YES;
        }
    } else if (aSelector == @selector(insertBacktab:)) {
        if ([self isInEmptyBulletedListItem] && [self isInEmptyNumberedListItem]) {
            [self userSelectedDecreaseIndent];
            return YES;
        }
    } else if (aSelector == @selector(deleteForward:)) {
        /// Do something against DELETE key
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeDelete];
    } else if (aSelector == @selector(deleteBackward:)) {
        /// Do something against BACKSPACE key
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeDelete];
    }
    
    return NO;
}

- (void)deleteBackward:(id)sender {
    self.justDeletedBackward = YES;
    [super deleteBackward:sender];
}

/// https://stackoverflow.com/a/23667851/3938401
- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag {
    if (charRange.length == 0) {
        self.lastAnchorPoint = charRange;
    }
    
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:charRange];
    charRange = [self adjustSelectedRangeFormatListWithBeginRange:rangeOfCurrentParagraph previousRange:NSMakeRange(NSNotFound, 0) currentRange:charRange isMouseClick:YES];
    [super setSelectedRange:charRange affinity:affinity stillSelecting:stillSelectingFlag];
}

/// https://stackoverflow.com/a/23667851/3938401
- (NSRange)textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange {
    if (newSelectedCharRange.length != 0) {
        int anchorStart = (int)self.lastAnchorPoint.location;
        int selectionStart = (int)newSelectedCharRange.location;
        int selectionLength = (int)newSelectedCharRange.length;
        
        /// If mouse selects left, and then a user arrows right, or the opposite, anchor point flips.
        int difference = anchorStart - selectionStart;
        if (difference > 0 && difference != selectionLength) {
            if (oldSelectedCharRange.location == newSelectedCharRange.location) {
                /// We were selecting left via mouse, but now we are selecting to the right via arrows
                anchorStart = selectionStart;
            } else {
                /// We were selecting right via mouse, but now we are selecting to the left via arrows
                anchorStart = selectionStart + selectionLength;
            }
            
            self.lastAnchorPoint = NSMakeRange(anchorStart, 0);
        }
        
        /// Evaluate Selection Direction
        if (anchorStart == selectionStart) {
            if (oldSelectedCharRange.length < newSelectedCharRange.length) {
                /// Bigger
                // NSLog(@"Will select right in overall right selection");
            } else {
                /// Smaller
                // NSLog(@"Will select left in overall right selection");
            }
            
            self.shouldEndColorChangeOnLeft = NO;
        } else {
            self.shouldEndColorChangeOnLeft = YES;
            
            if (oldSelectedCharRange.length < newSelectedCharRange.length) {
                /// Bigger
                // NSLog(@"Will select left in overall left selection");
            } else {
                /// Smaller
                // NSLog(@"Will select right in overall left selection");
            }
        }
        
        NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:oldSelectedCharRange];
        newSelectedCharRange = [self adjustSelectedRangeFormatListWithBeginRange:rangeOfCurrentParagraph previousRange:oldSelectedCharRange currentRange:newSelectedCharRange isMouseClick:NO];
    }
    
    if (self.delegate_interceptor.receiver && [self.delegate_interceptor.receiver respondsToSelector:@selector(textView:willChangeSelectionFromCharacterRange:toCharacterRange:)]) {
        return [self.delegate_interceptor.receiver textView:textView willChangeSelectionFromCharacterRange:oldSelectedCharRange toCharacterRange:newSelectedCharRange];
    }
    
    return newSelectedCharRange;
}

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    [self setNeedsLayout:YES];
    [self scrollRangeToVisible:[self selectedRange]]; // fixes issue with cursor moving to top via keyboard and RTE not scrolling
    [self sendDelegateTypingAttrsUpdate];
    
    if (self.delegate_interceptor.receiver && [self.delegate_interceptor.receiver respondsToSelector:@selector(textViewDidChangeSelection:)]) {
        [self.delegate_interceptor.receiver textViewDidChangeSelection:notification];
    }
}

- (void)textDidChange:(NSNotification *)notification {
    if (!self.isInTextDidChange) {
        self.isInTextDidChange = YES;
        [self applyListIfApplicableForType:RichTextEditorPreviewChangeBulletedList];
        [self deleteFormatListWhenApplicable:RichTextEditorPreviewChangeBulletedList];
        [self applyListIfApplicableForType:RichTextEditorPreviewChangeNumberingList];
        [self deleteFormatListWhenApplicable:RichTextEditorPreviewChangeNumberingList];
        
        if ([self.latestStringReplaced hasSuffix:@"\n"]) {
            /// Get rest of paragraph as they just deleted a newline
            NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:[self selectedRange]];
            NSInteger rangeDiff = [self selectedRange].location - rangeOfCurrentParagraph.location;
            NSString *bulletString = [RTELayoutManager kBulletString];
            NSString *numberingString = [RTELayoutManager kNumberingString];
            
            if (rangeDiff >= 0) {
                NSRange restOfLineRange = NSMakeRange(rangeOfCurrentParagraph.location + rangeDiff, rangeOfCurrentParagraph.length - rangeDiff);
                NSString *restOfLine = [self.string substringWithRange:restOfLineRange];
                
                if ([restOfLine hasPrefix:bulletString]) {
                    /// We must have deleted a newline under a previous list! Get rid of the bullet!
                    [[self textStorage] replaceCharactersInRange:NSMakeRange(restOfLineRange.location, bulletString.length) withString:@""];
                }
                
                if ([restOfLine hasPrefix:numberingString]) {
                    /// We must have deleted a newline under a previous list! Get rid of the numbering!
                    [[self textStorage] replaceCharactersInRange:NSMakeRange(restOfLineRange.location, numberingString.length) withString:@""];
                }
            }
        }
        
        self.isInTextDidChange = NO;
    }
    
    self.justDeletedBackward = NO;
    [self setNeedsUpdateLayout:YES];
    
    if (self.delegate_interceptor.receiver && [self.delegate_interceptor.receiver respondsToSelector:@selector(textDidChange:)]) {
        [self.delegate_interceptor.receiver textDidChange:notification];
    }
}

#pragma mark -

- (BOOL)isInBulletedList {
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:[self selectedRange]];
    return [[[self.attributedString string] substringFromIndex:rangeOfCurrentParagraph.location] hasPrefix:[RTELayoutManager kBulletString]];
}

- (BOOL)isInEmptyBulletedListItem {
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:[self selectedRange]];
    return [[[self.attributedString string] substringFromIndex:rangeOfCurrentParagraph.location] isEqualToString:[RTELayoutManager kBulletString]];
}

- (BOOL)isInNumberedList {
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:[self selectedRange]];
    return [[[self.attributedString string] substringFromIndex:rangeOfCurrentParagraph.location] hasPrefix:[RTELayoutManager kNumberingString]];
}

- (BOOL)isInEmptyNumberedListItem {
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:[self selectedRange]];
    return [[[self.attributedString string] substringFromIndex:rangeOfCurrentParagraph.location] isEqualToString:[RTELayoutManager kNumberingString]];
}

- (void)paste:(id)sender {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangePaste];
    
    if (self.allowsRichTextPasteOnlyFromThisClass) {
        if ([[NSPasteboard generalPasteboard] dataForType:[[self class] pasteboardDataType]]) {
            [super paste:sender]; // just call paste so we don't have to bother doing the check again
        } else {
            [self pasteAsPlainText:self];
        }
    } else {
        [super paste:sender];
    }
}

- (void)pasteAsRichText:(id)sender {
    BOOL hasCopyDataFromThisClass = [[NSPasteboard generalPasteboard] dataForType:[[self class] pasteboardDataType]] != nil;
    
    if (self.allowsRichTextPasteOnlyFromThisClass) {
        if (hasCopyDataFromThisClass) {
            [super pasteAsRichText:sender];
        } else {
            [self pasteAsPlainText:sender];
        }
    } else {
        [super pasteAsRichText:sender];
    }
}

- (void)pasteAsPlainText:(id)sender {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangePaste];
    
    /// Apparently paste as "plain" text doesn't ignore background and foreground colors...
    NSMutableDictionary *typingAttributes = [[self typingAttributes] mutableCopy];
    [typingAttributes removeObjectForKey:NSBackgroundColorAttributeName];
    [typingAttributes removeObjectForKey:NSForegroundColorAttributeName];
    
    [self setTypingAttributes:typingAttributes];
    [super pasteAsPlainText:sender];
}

- (void)cut:(id)sender {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeCut];
    [super cut:sender];
}

- (void)copy:(id)sender {
    [super copy:sender];
    NSPasteboard *currentPasteboard = [NSPasteboard generalPasteboard];
    [currentPasteboard setData:[@"" dataUsingEncoding:NSUTF8StringEncoding] forType:[[self class] pasteboardDataType]];
}

#pragma mark -

- (RTETextFormat *)typingTextFormat {
    NSDictionary *attributes = [self typingAttributes];
    NSFont *font = [attributes objectForKey:NSFontAttributeName];
    NSColor *fontColor = [attributes objectForKey:NSForegroundColorAttributeName];
    NSColor *backgroundColor = [attributes objectForKey:NSBackgroundColorAttributeName]; // may want NSBackgroundColorAttributeName
    RTETextFormat *textFormat = [[RTETextFormat alloc] init];
    textFormat.font = font;
    textFormat.isBold = [font isBold];
    textFormat.isItalic = [font isItalic];
    textFormat.isUnderline = [self isFontUnderlined];
    textFormat.isStrikethrough = [self isFontStrikethrough];
    textFormat.isBulletedList = [self isInBulletedList];
    textFormat.isNumberingList = [self isInNumberedList];
    textFormat.hyperlinkEnabled = [self isHyperlinkEnabled];
    textFormat.textAlignment = [self paragraphAlignment];
    textFormat.hyperlink = [self.attributedString hyperlinkFromTextRange:[self selectedRange]];
    textFormat.textColor = fontColor;
    textFormat.textBackgroundColor = backgroundColor;
    
    return textFormat;
}

- (void)sendDelegateTypingAttrsUpdate {
    if (self.rteDelegate && ([[self window] firstResponder] == self)) {
        RTETextFormat *textFormat = [self typingTextFormat];
        
        if (self.rteDelegate && [self.rteDelegate respondsToSelector:@selector(richTextEditor:changedSelectionTo:withFormat:)]) {
            [self.rteDelegate richTextEditor:self changedSelectionTo:[self selectedRange] withFormat:textFormat];
        }
    }
}

- (void)sendDelegateTVChanged {
    if (self.delegate_interceptor.receiver && [self.delegate_interceptor.receiver respondsToSelector:@selector(textDidChange:)]) {
        [self.delegate_interceptor.receiver textDidChange:[NSNotification notificationWithName:@"textDidChange:" object:self]];
    }
}

- (void)sendDelegatePreviewChangeOfType:(RichTextEditorPreviewChange)type {
    if (self.rteDelegate && [self.rteDelegate respondsToSelector:@selector(richTextEditor:changeAboutToOccurOfType:)]) {
        [self.rteDelegate richTextEditor:self changeAboutToOccurOfType:type];
    }
}

- (void)useSingleLineMode {
    NSScrollView *scrollView = self.enclosingScrollView;
    NSRect frame = [scrollView bounds];
    
    if (scrollView != nil) {
        self.usesSingleLineMode = YES;
        
        [scrollView setHasVerticalScroller:NO];
        [scrollView setHasHorizontalScroller:NO];
        [scrollView setVerticalScrollElasticity:NSScrollElasticityNone];
        [scrollView setHorizontalScrollElasticity:NSScrollElasticityAllowed];
        [scrollView setContentInsets:NSEdgeInsetsZero];
        [scrollView setScrollerInsets:NSEdgeInsetsMake(0, 0, -NSHeight([scrollView.horizontalScroller frame]), -NSHeight([scrollView.verticalScroller frame]))];
        [self setMaxSize:NSMakeSize(FLT_MAX, NSHeight(frame))];
        [self setHorizontallyResizable:YES];
        [self setVerticallyResizable:NO];
        [self setTextContainerInset:NSZeroSize];
        [[self textContainer] setContainerSize:NSMakeSize(FLT_MAX, NSHeight(frame))];
        [[self textContainer] setWidthTracksTextView:NO];
        [[self textContainer] setHeightTracksTextView:NO];
        [[self textContainer] setMaximumNumberOfLines:1];
    }
}

- (void)userSelectedBold {
    [self performBlockWithRestoringScrollLocation:^{
        NSFont *font = [[self typingAttributes] objectForKey:NSFontAttributeName];
        
        if (!font) {
            font = [NSFont systemFontOfSize:12.0f];
        }
        
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeBold];
        [self applyFontAttributesToSelectedRangeWithBoldTrait:[NSNumber numberWithBool:![font isBold]] italicTrait:nil fontName:nil fontSize:nil];
        [self sendDelegateTypingAttrsUpdate];
        [self sendDelegateTVChanged];
    }];
}

- (void)userSelectedItalic {
    [self performBlockWithRestoringScrollLocation:^{
        NSFont *font = [[self typingAttributes] objectForKey:NSFontAttributeName];
        
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeItalic];
        [self applyFontAttributesToSelectedRangeWithBoldTrait:nil italicTrait:[NSNumber numberWithBool:![font isItalic]] fontName:nil fontSize:nil];
        [self sendDelegateTypingAttrsUpdate];
        [self sendDelegateTVChanged];
    }];
}

- (void)userSelectedUnderline {
    [self performBlockWithRestoringScrollLocation:^{
        NSNumber *existingUnderlineStyle;
        
        if (![self isFontUnderlined]) {
            existingUnderlineStyle = [NSNumber numberWithInteger:NSUnderlineStyleSingle];
        } else {
            existingUnderlineStyle = [NSNumber numberWithInteger:NSUnderlineStyleNone];
        }
        
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeUnderline];
        [self applyAttributesToSelectedRange:existingUnderlineStyle forKey:NSUnderlineStyleAttributeName];
        [self sendDelegateTypingAttrsUpdate];
        [self sendDelegateTVChanged];
    }];
}

- (void)userSelectedStrikethrough {
    [self performBlockWithRestoringScrollLocation:^{
        NSNumber *existingUnderlineStyle;
        
        if (![self isFontStrikethrough]) {
            existingUnderlineStyle = [NSNumber numberWithInteger:NSUnderlineStyleSingle];
        } else {
            existingUnderlineStyle = [NSNumber numberWithInteger:NSUnderlineStyleNone];
        }
        
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeStrikethrough];
        [self applyAttributesToSelectedRange:existingUnderlineStyle forKey:NSStrikethroughStyleAttributeName];
        [self sendDelegateTypingAttrsUpdate];
        [self sendDelegateTVChanged];
    }];
}

- (void)userSelectedIncreaseIndent {
    [self performBlockWithRestoringScrollLocation:^{
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeIndentIncrease];
        [self userSelectedParagraphIndentation:ParagraphIndentationIncrease];
        [self sendDelegateTVChanged];
    }];
}

- (void)userSelectedDecreaseIndent {
    [self performBlockWithRestoringScrollLocation:^{
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeIndentDecrease];
        [self userSelectedParagraphIndentation:ParagraphIndentationDecrease];
        [self sendDelegateTVChanged];
    }];
}

- (void)userSelectedTextBackgroundColor:(NSColor *)color {
    [self performBlockWithRestoringScrollLocation:^{
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeHighlight];
        NSRange selectedRange = [self selectedRange];
        
        if (color) {
            [self applyAttributesToSelectedRange:color forKey:NSBackgroundColorAttributeName];
        } else {
            [self removeAttributeForKeyFromSelectedRange:NSBackgroundColorAttributeName];
        }
        
        if (self.shouldEndColorChangeOnLeft) {
            [self setSelectedRange:NSMakeRange(selectedRange.location, 0)];
        } else {
            [self setSelectedRange:NSMakeRange(selectedRange.location + selectedRange.length, 0)];
        }
        
        [self sendDelegateTVChanged];
    }];
}

- (void)userSelectedTextColor:(NSColor *)color {
    [self performBlockWithRestoringScrollLocation:^{
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeFontColor];
        
        if (color) {
            [self applyAttributesToSelectedRange:color forKey:NSForegroundColorAttributeName];
        } else {
            [self removeAttributeForKeyFromSelectedRange:NSForegroundColorAttributeName];
        }
        
        [self sendDelegateTVChanged];
    }];
}

- (void)userApplyHyperlink:(NSURL *_Nullable)url {
    [self userApplyHyperlink:url color:[NSColor blueColor] underlineStyle:NSUnderlineStyleSingle];
}

- (void)userApplyHyperlink:(NSURL *_Nullable)url color:(NSColor *_Nullable)color {
    [self userApplyHyperlink:url color:[NSColor blueColor] underlineStyle:NSUnderlineStyleSingle];
}

- (void)userApplyHyperlink:(NSURL *_Nullable)url color:(NSColor *_Nullable)color underlineStyle:(NSUnderlineStyle)underlineStyle {
    [self performBlockWithRestoringScrollLocation:^{
        ///
        [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeHyperLink];
        
        if (url) {
            [self applyAttributesToSelectedRange:[url absoluteString] forKey:NSLinkAttributeName];
            
            ///
            [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeFontColor];
            
            if (color) {
                [self applyAttributesToSelectedRange:color forKey:NSForegroundColorAttributeName];
            } else {
                [self removeAttributeForKeyFromSelectedRange:NSForegroundColorAttributeName];
            }
            
            ///
            [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeUnderline];
            [self applyAttributesToSelectedRange:[NSNumber numberWithInteger:underlineStyle] forKey:NSUnderlineStyleAttributeName];
            [self sendDelegateTypingAttrsUpdate];
        } else {
            [self removeAttributeForKeyFromSelectedRange:NSLinkAttributeName];
            [self removeAttributeForKeyFromSelectedRange:NSForegroundColorAttributeName];
            [self applyAttributesToSelectedRange:[NSNumber numberWithInteger:NSUnderlineStyleNone] forKey:NSUnderlineStyleAttributeName];
        }
        
        [self sendDelegateTVChanged];
    }];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
}

#pragma mark - Public Methods -

- (void)setWidthTracksTextView:(BOOL)widthTracksTextView {
    [[self textContainer] setWidthTracksTextView:widthTracksTextView];
}

- (void)setHeightTracksTextView:(BOOL)heightTracksTextView {
    [[self textContainer] setHeightTracksTextView:heightTracksTextView];
}

- (void)setLineFragmentPadding:(CGFloat)padding {
    [[self textContainer] setLineFragmentPadding:padding];
}

- (void)setMaximumNumberOfLines:(CGFloat)numberOfLines {
    if (self.usesSingleLineMode) {
        [[self textContainer] setMaximumNumberOfLines:1];
    } else {
        [[self textContainer] setMaximumNumberOfLines:numberOfLines];
    }
}

- (void)setBulletNumberingColor:(NSColor *)bulletNumberingColor {
    _bulletNumberingColor = bulletNumberingColor;
    
    [[[self layoutManager] RTEInstance] setBulletNumberingColor:bulletNumberingColor];
}

- (void)setBulletNumberingIndent:(CGFloat)bulletNumberingIndent {
    _bulletNumberingIndent = bulletNumberingIndent;
    
    [[[self layoutManager] RTEInstance] setBulletNumberingIndent:bulletNumberingIndent];
}

- (void)setFirstLineHeadIndent:(CGFloat)firstLineHeadIndent {
    _firstLineHeadIndent = firstLineHeadIndent;
    
    [[[self layoutManager] RTEInstance] setFirstLineHeadIndent:firstLineHeadIndent];
}

+ (BOOL)isHTML:(NSString *)string {
    /// https://stackoverflow.com/a/6817767
    /// /<(\w+)(\s+(\w+)(\s*\=\s*(\'|"|)(.*?)\\5\s*)?)*\s*>/
    /// Understanding the pattern
    ///
    /// If someone is interested in learning more about the pattern, I provide some line:
    ///
    /// 1. the first sub-expression (\w+) matches the tag name
    /// 2. the second sub-expression contains the pattern of an attribute. It is composed by:
    ///     2.1 one or more whitespaces \s+
    ///     2.2 the name of the attribute (\w+)
    ///     2.3 zero or more whitespaces \s* (it is possible or not, leaving blanks here)
    ///     2.4 the "=" symbol
    ///     2.5 again, zero or more whitespaces
    ///     2.6 the delimiter of the attribute value, a single or double quote ('|"). In the pattern, the single quote is escaped because it coincides with the PHP string delimiter. This sub-expression is captured with the parentheses so it can be referenced again to parse the closure of the attribute, that's why it is very important.
    ///     2.7 the value of the attribute, matched by almost anything: (.*?); in this specific syntax, using the greedy match (the question mark after the asterisk) the RegExp engine enables a "look-ahead"-like operator, which matches anything but what follows this sub-expression
    ///     2.8 here comes the fun: the \4 part is a backreference operator, which refers to a sub-expression defined before in the pattern, in this case, I am referring to the fourth sub-expression, which is the first attribute delimiter found
    ///     2.9 zero or more whitespaces \s*
    ///     2.10 the attribute sub-expression ends here, with the specification of zero or more possible occurrences, given by the asterisk.
    /// 3. Then, since a tag may end with a whitespace before the ">" symbol, zero or more whitespaces are matched with the \s* subpattern.
    /// 4. The tag to match may end with a simple ">" symbol, or a possible XHTML closure, which makes use of the slash before it: (/>|>). The slash is, of course, escaped since it coincides with the regular expression delimiter.
    NSRange range = NSMakeRange(0, [string length]);
    NSString *pattern = @"<(\\w+)(\\s+(\\w+)(\\s*\\=\\s*(\'|\"|)(.*?)\\5\\s*)?)*\\s*>";
    NSError  *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSArray *matches = [regex matchesInString:string options:0 range:range];
    
    return (matches.count > 0);
}

- (void)setHtmlString:(NSString *)htmlString {
    NSMutableAttributedString *attr = [[[self class] attributedStringFromHTMLString:htmlString] mutableCopy];
    
    if (attr) {
        if ([attr.string hasSuffix:@"\n"]) {
            [attr replaceCharactersInRange:NSMakeRange(attr.length - 1, 1) withString:@""];
        }
        
        [self setAttributedString:attr];
    }
}

- (NSString *)htmlString {
    return [[self class] htmlStringFromAttributedText:self.attributedString];
}

+ (NSAttributedString *)encodingNonLossyASCIIAttributedText:(NSAttributedString *)attributedText {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedText];
    NSString *bulletString = [RTELayoutManager kBulletString];
    NSString *numberingString = [RTELayoutManager kNumberingString];
    NSString *encodedBulletString = [RTELayoutManager kEncodedBulletString];
    NSString *encodedNumberingString = [RTELayoutManager kEncodedNumberingString];
    __block NSInteger rangeOffset = 0;
    
    [attributedText enumarateParagraphsInRange:NSMakeRange(0, attributedText.length) withBlock:^(NSRange paragraphRange) {
        NSRange range = [attributedString firstParagraphRangeFromTextRange:NSMakeRange(paragraphRange.location + rangeOffset, paragraphRange.length)];
        NSDictionary *dictionary = [attributedString attributesAtIndex:MAX((int)range.location, 0)];
        NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
        
        if (!paragraphStyle) {
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        
        BOOL currentParagraphHasBullet = [[attributedString.string substringFromIndex:range.location] hasPrefix:bulletString];
        
        if (currentParagraphHasBullet) {
            NSMutableAttributedString *replacingString = [[NSMutableAttributedString alloc] initWithString:encodedBulletString attributes:nil];
            [replacingString setAttributes:dictionary range:NSMakeRange(0, replacingString.string.length)];
            
            [attributedString replaceCharactersInRange:NSMakeRange(range.location, bulletString.length) withAttributedString:replacingString];
            
            rangeOffset = rangeOffset + replacingString.length - bulletString.length;
        }
        
        BOOL currentParagraphHasNumbering = [[attributedString.string substringFromIndex:range.location] hasPrefix:numberingString];
        
        if (currentParagraphHasNumbering) {
            NSMutableAttributedString *replacingString = [[NSMutableAttributedString alloc] initWithString:encodedNumberingString attributes:nil];
            [replacingString setAttributes:dictionary range:NSMakeRange(0, replacingString.string.length)];
            
            [attributedString replaceCharactersInRange:NSMakeRange(range.location, numberingString.length) withAttributedString:replacingString];
            
            rangeOffset = rangeOffset + replacingString.length - numberingString.length;
        }
    }];
    
    return attributedString;
}

+ (NSAttributedString *)decodingNonLossyASCIIAttributedText:(NSAttributedString *)attributedText {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedText];
    NSString *bulletString = [RTELayoutManager kBulletString];
    NSString *numberingString = [RTELayoutManager kNumberingString];
    NSString *encodedBulletString = [RTELayoutManager kEncodedBulletString];
    NSString *encodedNumberingString = [RTELayoutManager kEncodedNumberingString];
    __block NSInteger rangeOffset = 0;
    
    [attributedText enumarateParagraphsInRange:NSMakeRange(0, attributedString.length) withBlock:^(NSRange paragraphRange) {
        NSRange range = [attributedString firstParagraphRangeFromTextRange:NSMakeRange(paragraphRange.location + rangeOffset, paragraphRange.length)];
        NSDictionary *dictionary = [attributedString attributesAtIndex:MAX((int)range.location, 0)];
        NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
        
        if (!paragraphStyle) {
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        
        BOOL currentParagraphHasBullet = [[attributedString.string substringFromIndex:range.location] hasPrefix:encodedBulletString];
        
        if (currentParagraphHasBullet) {
            NSMutableAttributedString *replacingString = [[NSMutableAttributedString alloc] initWithString:bulletString attributes:nil];
            [replacingString setAttributes:dictionary range:NSMakeRange(0, replacingString.string.length)];
            
            [attributedString replaceCharactersInRange:NSMakeRange(range.location, encodedBulletString.length) withAttributedString:replacingString];
            
            rangeOffset = rangeOffset + replacingString.length - encodedBulletString.length;
        }
        
        BOOL currentParagraphHasNumbering = [[attributedString.string substringFromIndex:range.location] hasPrefix:encodedNumberingString];
        
        if (currentParagraphHasNumbering) {
            NSMutableAttributedString *replacingString = [[NSMutableAttributedString alloc] initWithString:numberingString attributes:nil];
            [replacingString setAttributes:dictionary range:NSMakeRange(0, replacingString.string.length)];
            
            [attributedString replaceCharactersInRange:NSMakeRange(range.location, encodedNumberingString.length) withAttributedString:replacingString];
            
            rangeOffset = rangeOffset + replacingString.length - encodedNumberingString.length;
        }
    }];
    
    return attributedString;
}

+ (NSString *)htmlStringFromAttributedText:(NSAttributedString *)attributedText {
    NSString *string = [attributedText.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (string.length > 0) {
        NSAttributedString *attributedString = [[self class] encodingNonLossyASCIIAttributedText:attributedText];
        NSData *data = [attributedString dataFromRange:NSMakeRange(0, attributedString.length)
                                    documentAttributes:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                         NSCharacterEncodingDocumentAttribute: [NSNumber numberWithUnsignedInteger:NSUTF8StringEncoding]}
                                                 error:nil];
        
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    return string;
}

+ (NSAttributedString *)attributedStringFromHTMLString:(NSString *)htmlString {
    return [[self class] attributedStringFromHTMLString:htmlString defaultFont:nil];
}

+ (NSAttributedString *)attributedStringFromHTMLString:(NSString *)htmlString defaultFont:(NSFont *)defaultFont {
    @try {
        if ([[self class] isHTML:htmlString]) {
            NSError *error;
            NSData *data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
            NSAttributedString *attributedString = [[NSAttributedString alloc] initWithData:data
                                                                                    options:@{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                                              NSCharacterEncodingDocumentAttribute: [NSNumber numberWithUnsignedInteger:NSUTF8StringEncoding]}
                                                                         documentAttributes:nil
                                                                                      error:&error
                                                                                defaultFont:defaultFont];
            
            if (attributedString.length > 0) {
                NSAttributedString *replacedString = [[self class] replacingBulletsIfApplicableForAttributedText:[[self class] decodingNonLossyASCIIAttributedText:attributedString]];
                NSAttributedString *bulletedListString = [[self class] applyFormatListIfApplicableForAttributedText:replacedString withType:RichTextEditorPreviewChangeBulletedList];
                NSAttributedString *numberingListString = [[self class] applyFormatListIfApplicableForAttributedText:bulletedListString withType:RichTextEditorPreviewChangeNumberingList];
                
                return numberingListString;
            }
            
            return nil;
        }
        
        return  [[NSAttributedString alloc] initWithString:htmlString];
    } @catch (NSException *e) {
        NSLog(@"%s [Line %d] failed with exception: %@", __PRETTY_FUNCTION__, __LINE__, e);
        return nil;
    }
}

- (void)setAttributedString:(NSAttributedString *)attributedString {
    [[self textStorage] setAttributedString:attributedString];
}

+ (NSAttributedString *)replacingBulletsIfApplicableForAttributedText:(NSAttributedString *)attributedText {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedText];
    
    NSString *replacingBullet = [NSString stringWithFormat:@"•%@", kNonBreakingSpace];
    NSString *bulletString = [RTELayoutManager kBulletString];
    CGFloat firstLineHeadIndent = kFirstLineHeadIndent;
    __block NSInteger rangeOffset = 0;
    
    [attributedText enumarateParagraphsInRange:NSMakeRange(0, attributedText.length) withBlock:^(NSRange paragraphRange) {
        NSRange range = NSMakeRange(paragraphRange.location + rangeOffset, paragraphRange.length);
        NSDictionary *dictionary = [attributedString attributesAtIndex:MAX((int)range.location, 0)];
        NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
        
        if (!paragraphStyle) {
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        
        BOOL currentParagraphHasBullet = [[attributedString.string substringFromIndex:range.location] hasPrefix:replacingBullet];
        
        if (currentParagraphHasBullet) {
            /// Should remove the old bullet first
            range = NSMakeRange(range.location, range.length - replacingBullet.length);
            [attributedString deleteCharactersInRange:NSMakeRange(range.location, replacingBullet.length)];
            paragraphStyle.firstLineHeadIndent = 0;
            paragraphStyle.headIndent = 0;
            rangeOffset = rangeOffset - replacingBullet.length;
            
            /// We are adding a bullet
            range = NSMakeRange(range.location, range.length + bulletString.length);
            
            NSMutableAttributedString *bulletAttributedString = [[NSMutableAttributedString alloc] initWithString:bulletString attributes:nil];
            [bulletAttributedString setAttributes:dictionary range:NSMakeRange(0, bulletString.length)];
            
            [attributedString insertAttributedString:bulletAttributedString atIndex:range.location];
            
            CGSize expectedStringSize = [bulletString sizeWithAttributes:dictionary];
            
            paragraphStyle.firstLineHeadIndent = firstLineHeadIndent;
            paragraphStyle.headIndent = expectedStringSize.width + paragraphStyle.firstLineHeadIndent;
            
            rangeOffset = rangeOffset + bulletString.length;
            
            [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
        }
    }];
    
    return attributedString;
}

+ (NSAttributedString *)applyFormatListIfApplicableForAttributedText:(NSAttributedString *)attributedText withType:(RichTextEditorPreviewChange)formatType {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:attributedText];
    
    if ((formatType != RichTextEditorPreviewChangeBulletedList) && (formatType != RichTextEditorPreviewChangeNumberingList)) return attributedString;
    
    NSString *formatListString = (formatType == RichTextEditorPreviewChangeBulletedList) ? [RTELayoutManager kBulletString] : [RTELayoutManager kNumberingString];
    CGFloat firstLineHeadIndent = kFirstLineHeadIndent;
    __block NSInteger rangeOffset = 0;
    
    [attributedText enumarateParagraphsInRange:NSMakeRange(0, attributedText.length) withBlock:^(NSRange paragraphRange) {
        NSRange range = NSMakeRange(paragraphRange.location + rangeOffset, paragraphRange.length);
        NSDictionary *dictionary = [attributedString attributesAtIndex:MAX((int)range.location, 0)];
        NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
        
        if (!paragraphStyle) {
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        
        BOOL currentParagraphHasFormatList = [[attributedString.string substringFromIndex:range.location] hasPrefix:formatListString];
        
        if (currentParagraphHasFormatList) {
            /// Should remove the old bullet first
            range = NSMakeRange(range.location, range.length - formatListString.length);
            [attributedString deleteCharactersInRange:NSMakeRange(range.location, formatListString.length)];
            paragraphStyle.firstLineHeadIndent = 0;
            paragraphStyle.headIndent = 0;
            rangeOffset = rangeOffset - formatListString.length;
            
            /// We are adding a bullet
            range = NSMakeRange(range.location, range.length + formatListString.length);
            
            NSMutableAttributedString *formatListAttributedString = [[NSMutableAttributedString alloc] initWithString:formatListString attributes:nil];
            [formatListAttributedString setAttributes:dictionary range:NSMakeRange(0, formatListString.length)];
            
            [attributedString insertAttributedString:formatListAttributedString atIndex:range.location];
            
            CGSize expectedStringSize = [formatListString sizeWithAttributes:dictionary];
            
            paragraphStyle.firstLineHeadIndent = firstLineHeadIndent;
            paragraphStyle.headIndent = expectedStringSize.width + paragraphStyle.firstLineHeadIndent;
            
            rangeOffset = rangeOffset + formatListString.length;
        }
        
        [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
    }];
    
    return attributedString;
}

- (void)setBorderColor:(NSColor *)borderColor {
    self.layer.borderColor = borderColor.CGColor;
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    self.layer.borderWidth = borderWidth;
}

- (void)userChangedToFontSize:(NSNumber *)fontSize {
    [self performBlockWithRestoringScrollLocation:^{
        [self applyFontAttributesToSelectedRangeWithBoldTrait:nil italicTrait:nil fontName:nil fontSize:fontSize];
        [self setNeedsUpdateLayout:YES];
    }];
}

- (void)userChangedToFontName:(NSString *)fontName {
    [self performBlockWithRestoringScrollLocation:^{
        [self applyFontAttributesToSelectedRangeWithBoldTrait:nil italicTrait:nil fontName:fontName fontSize:nil];
        [self setNeedsUpdateLayout:YES];
    }];
}

- (BOOL)isFontUnderlined {
    NSDictionary *dictionary = [self typingAttributes];
    NSNumber *existingUnderlineStyle = [dictionary objectForKey:NSUnderlineStyleAttributeName];
    
    if (!existingUnderlineStyle || existingUnderlineStyle.intValue == NSUnderlineStyleNone) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isFontStrikethrough {
    NSDictionary *dictionary = [self typingAttributes];
    NSNumber *existingStrikethroughStyle = [dictionary objectForKey:NSStrikethroughStyleAttributeName];
    
    if (!existingStrikethroughStyle || existingStrikethroughStyle.intValue == NSUnderlineStyleNone) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isHyperlinkEnabled {
    NSRange selectedRange = [self selectedRange];
    
    if (selectedRange.length > 0) {
        NSInteger start = selectedRange.location;
        NSInteger end = selectedRange.location + selectedRange.length;
        NSInteger hyperlinkLength = 0;
        
        for (NSInteger location = start; location < end; ++location) {
            NSDictionary *dictionary = [self dictionaryAtIndex:location];
            NSURL *url = [dictionary objectForKey:NSLinkAttributeName];
            
            if (url != nil) {
                ++hyperlinkLength;
            }
        }
        
        if ((hyperlinkLength == 0) || (hyperlinkLength == (end - start))) {
            return YES;
        }
    }
    
    return NO;
}

/// try/catch blocks on undo/redo because it doesn't work right with bulleted lists when kBulletString has more than 1 character
- (void)undo {
    @try {
        BOOL shouldUseUndoManager = YES;
        
        if ([self.rteDelegate respondsToSelector:@selector(richTextEditorHandlesUndoRedoForText:)] &&
            [self.rteDelegate respondsToSelector:@selector(richTextEditorPerformedUndo:)]) {
            if ([self.rteDelegate richTextEditorHandlesUndoRedoForText:self]) {
                [self.rteDelegate richTextEditorPerformedUndo:self];
                shouldUseUndoManager = NO;
            }
        }
        
        if (shouldUseUndoManager && [[self undoManager] canUndo]) {
            [[self undoManager] undo];
        }
    } @catch (NSException *e) {
        [[self undoManager] removeAllActions];
    }
}

- (void)redo {
    @try {
        BOOL shouldUseUndoManager = YES;
        
        if ([self.rteDelegate respondsToSelector:@selector(richTextEditorHandlesUndoRedoForText:)] &&
            [self.rteDelegate respondsToSelector:@selector(richTextEditorPerformedRedo:)]) {
            if ([self.rteDelegate richTextEditorHandlesUndoRedoForText:self]) {
                [self.rteDelegate richTextEditorPerformedRedo:self];
                shouldUseUndoManager = NO;
            }
        }
        
        if (shouldUseUndoManager && [[self undoManager] canRedo]) {
            [[self undoManager] redo];
        }
    } @catch (NSException *e) {
        [[self undoManager] removeAllActions];
    }
}

- (void)userSelectedParagraphIndentation:(ParagraphIndentation)paragraphIndentation {
    self.isInTextDidChange = YES;
    __block NSDictionary *dictionary;
    __block NSMutableParagraphStyle *paragraphStyle;
    NSRange currSelectedRange = [self selectedRange];
    
    [self enumarateThroughParagraphsInRange:[self selectedRange] withBlock:^(NSRange paragraphRange) {
        dictionary = [self dictionaryAtIndex:paragraphRange.location];
        paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
        
        if (!paragraphStyle) {
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        
        if (paragraphIndentation == ParagraphIndentationIncrease &&
            paragraphStyle.headIndent < self.MAX_INDENT && paragraphStyle.firstLineHeadIndent < self.MAX_INDENT) {
            paragraphStyle.headIndent += self.firstLineHeadIndent;
            paragraphStyle.firstLineHeadIndent += self.firstLineHeadIndent;
        } else if (paragraphIndentation == ParagraphIndentationDecrease) {
            paragraphStyle.headIndent -= self.firstLineHeadIndent;
            paragraphStyle.firstLineHeadIndent -= self.firstLineHeadIndent;
            
            if (paragraphStyle.headIndent < 0) {
                paragraphStyle.headIndent = 0; /// this is the right cursor placement
            }
            
            if (paragraphStyle.firstLineHeadIndent < 0) {
                paragraphStyle.firstLineHeadIndent = 0; /// this affects left cursor placement
            }
        }
        
        [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:paragraphRange];
    }];
    
    [self setSelectedRange:currSelectedRange];
    self.isInTextDidChange = NO;
    // Old iOS code
    // Following 2 lines allow the user to insta-type after indenting in a bulleted list
    //NSRange range = NSMakeRange([self selectedRange].location+[self selectedRange].length, 0);
    //[self setSelectedRange:range];
    // Check to see if the current paragraph is blank. If it is, manually get the cursor to move with a weird hack.
    
    // After NSTextStorage changes, these don't seem necessary
    /* NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:[self selectedRange]];
     BOOL currParagraphIsBlank = [[self.string substringWithRange:rangeOfCurrentParagraph] isEqualToString:@""] ? YES: NO;
     if (currParagraphIsBlank)
     {
     // [self setIndentationWithAttributes:dictionary paragraphStyle:paragraphStyle atRange:rangeOfCurrentParagraph];
     } */
}

/// Manually ensures that the cursor is shown in the correct location. Ugly work around and weird but it works (at least in iOS 7 / OS X 10.11.2).
/// Basically what I do is add a " " with the correct indentation then delete it. For some reason with that
/// and applying that attribute to the current typing attributes it moves the cursor to the right place.
/// Would updating the typing attributes also work instead? That'd certainly be cleaner...
- (void)setIndentationWithAttributes:(NSDictionary *)attributes paragraphStyle:(NSMutableParagraphStyle *)paragraphStyle atRange:(NSRange)range {
    NSMutableAttributedString *space = [[NSMutableAttributedString alloc] initWithString:@" " attributes:attributes];
    [space addAttributes:[NSDictionary dictionaryWithObject:paragraphStyle forKey:NSParagraphStyleAttributeName] range:NSMakeRange(0, 1)];
    [[self textStorage] insertAttributedString:space atIndex:range.location];
    [self setSelectedRange:NSMakeRange(range.location, 1)];
    [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:NSMakeRange([self selectedRange].location + [self selectedRange].length - 1, 1)];
    [self setSelectedRange:NSMakeRange(range.location, 0)];
    [[self textStorage] deleteCharactersInRange:NSMakeRange(range.location, 1)];
    [self applyAttributeToTypingAttribute:paragraphStyle forKey:NSParagraphStyleAttributeName];
}

- (void)userSelectedParagraphFirstLineHeadIndent {
    [self performBlockWithRestoringScrollLocation:^{
        [self enumarateThroughParagraphsInRange:[self selectedRange] withBlock:^(NSRange paragraphRange) {
            NSDictionary *dictionary = [self dictionaryAtIndex:paragraphRange.location];
            NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
            
            if (!paragraphStyle) {
                paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            }
            
            if (paragraphStyle.headIndent == paragraphStyle.firstLineHeadIndent) {
                paragraphStyle.firstLineHeadIndent += self.firstLineHeadIndent;
            } else {
                paragraphStyle.firstLineHeadIndent = paragraphStyle.headIndent;
            }
            
            [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:paragraphRange];
        }];
    }];
}

- (NSTextAlignment)paragraphAlignment {
    NSArray *rangeOfParagraphsInSelectedText = [self.attributedString rangeOfParagraphsFromTextRange:[self selectedRange]];
    NSRange paragraphRange = [[rangeOfParagraphsInSelectedText lastObject] rangeValue];
    NSDictionary *dictionary = [self dictionaryAtIndex:paragraphRange.location];
    NSParagraphStyle *paragraphStyle = [dictionary objectForKey:NSParagraphStyleAttributeName];
    
    if (paragraphStyle != nil) {
        return paragraphStyle.alignment;
    }
    
    return NSTextAlignmentLeft;
}

- (void)userSelectedTextAlignment:(NSTextAlignment)textAlignment {
    [self performBlockWithRestoringScrollLocation:^{
        [self enumarateThroughParagraphsInRange:[self selectedRange] withBlock:^(NSRange paragraphRange) {
            NSDictionary *dictionary = [self dictionaryAtIndex:paragraphRange.location];
            NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
            
            if (!paragraphStyle) {
                paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            }
            
            paragraphStyle.alignment = textAlignment;
            
            [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:paragraphRange];
            [self setIndentationWithAttributes:dictionary paragraphStyle:paragraphStyle atRange:paragraphRange];
        }];
    }];
}

/// http://stackoverflow.com/questions/5810706/how-to-programmatically-add-bullet-list-to-nstextview might be useful to look at some day (or maybe not)
- (void)userSelectedBulletedList {
    [self performBlockWithRestoringScrollLocation:^{
        [self userSelectedFormatListWithType:RichTextEditorPreviewChangeBulletedList];
        [self setNeedsUpdateLayout:YES];
    }];
}

- (void)userSelectedNumberingList {
    [self performBlockWithRestoringScrollLocation:^{
        [self userSelectedFormatListWithType:RichTextEditorPreviewChangeNumberingList];
        [self setNeedsUpdateLayout:YES];
    }];
}

- (void)userSelectedFormatListWithType:(RichTextEditorPreviewChange)formatType {
    if ((formatType != RichTextEditorPreviewChangeBulletedList) && (formatType != RichTextEditorPreviewChangeNumberingList)) return;
    
    if (!self.isEditable) {
        return;
    }
    
    [self sendDelegatePreviewChangeOfType:formatType];
    [self deleteMultipleFormatListsIfApplicable:formatType];
    
    NSRange selectedRange = [self selectedRange];
    NSString *formatListString = (formatType == RichTextEditorPreviewChangeBulletedList) ? [RTELayoutManager kBulletString] : [RTELayoutManager kNumberingString];
    NSString *otherFormatListString = (formatType == RichTextEditorPreviewChangeBulletedList) ? [RTELayoutManager kNumberingString] : [RTELayoutManager kBulletString];
    NSRange initialSelectedRange = selectedRange;
    NSArray *rangeOfParagraphsInSelectedText = [self.attributedString rangeOfParagraphsFromTextRange:selectedRange];
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:selectedRange];
    BOOL firstParagraphHasFormatList = [[self.string substringFromIndex:rangeOfCurrentParagraph.location] hasPrefix:formatListString];
    
    __block NSInteger rangeOffset = 0;
    __block BOOL mustDecreaseIndentAfterRemovingFormatList = NO;
    __block BOOL isInFormatList = self.inBulletedList || self.inNumberedList;
    
    [self enumarateThroughParagraphsInRange:selectedRange withBlock:^(NSRange paragraphRange) {
        NSRange range = NSMakeRange(paragraphRange.location + rangeOffset, paragraphRange.length);
        NSDictionary *dictionary = [self dictionaryAtIndex:MAX((int)range.location, 0)];
        NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
        
        if (!paragraphStyle) {
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        
        BOOL currentParagraphHasFormatList = [[self.string substringFromIndex:range.location] hasPrefix:formatListString];
        BOOL currentParagraphHasOtherFormatList = [[self.string substringFromIndex:range.location] hasPrefix:otherFormatListString];
        
        if (firstParagraphHasFormatList != currentParagraphHasFormatList) {
            return;
        }
        
        if (currentParagraphHasOtherFormatList) {
            /// User hit the bullet button and is in a bulleted list so we should get rid of the bullet
            range = NSMakeRange(range.location, range.length - otherFormatListString.length);
            
            [[self textStorage] deleteCharactersInRange:NSMakeRange(range.location, otherFormatListString.length)];
            
            paragraphStyle.firstLineHeadIndent = 0;
            paragraphStyle.headIndent = 0;
            
            rangeOffset = rangeOffset - otherFormatListString.length;
        }
        
        if (currentParagraphHasFormatList) {
            /// User hit the bullet button and is in a bulleted list so we should get rid of the bullet
            range = NSMakeRange(range.location, range.length - formatListString.length);
            
            [[self textStorage] deleteCharactersInRange:NSMakeRange(range.location, formatListString.length)];
            
            paragraphStyle.firstLineHeadIndent = 0;
            paragraphStyle.headIndent = 0;
            
            rangeOffset = rangeOffset - formatListString.length;
            mustDecreaseIndentAfterRemovingFormatList = YES;
            isInFormatList = NO;
        } else {
            /// We are adding a bullet
            range = NSMakeRange(range.location, range.length + formatListString.length);
            
            NSMutableAttributedString *formatListAttributedString = [[NSMutableAttributedString alloc] initWithString:formatListString attributes:nil];
            /// The following code attempts to remove any underline from the bullet string, but it doesn't work right. I don't know why.
            /*  NSFont *prevFont = [dictionary objectForKey:NSFontAttributeName];
             NSFont *bulletFont = [NSFont fontWithName:[prevFont familyName] size:[prevFont pointSize]];
             
             NSMutableDictionary *bulletDict = [dictionary mutableCopy];
             [bulletDict setObject:bulletFont forKey:NSFontAttributeName];
             [bulletDict removeObjectForKey:NSStrikethroughStyleAttributeName];
             [bulletDict setValue:NSUnderlineStyleNone forKey:NSUnderlineStyleAttributeName];
             [bulletDict removeObjectForKey:NSStrokeColorAttributeName];
             [bulletDict removeObjectForKey:NSStrokeWidthAttributeName];
             dictionary = bulletDict;*/
            
            [formatListAttributedString setAttributes:dictionary range:NSMakeRange(0, formatListString.length)];
            
            [[self textStorage] insertAttributedString:formatListAttributedString atIndex:range.location];
            
            CGSize expectedStringSize = [formatListString sizeWithAttributes:dictionary];
            
            paragraphStyle.firstLineHeadIndent = self.firstLineHeadIndent;
            paragraphStyle.headIndent = expectedStringSize.width + paragraphStyle.firstLineHeadIndent;
            
            rangeOffset = rangeOffset + formatListString.length;
            isInFormatList = YES;
        }
        
        [[self textStorage] addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
    }];
    
    /// If paragraph is empty move cursor to front of bullet, so the user can start typing right away
    NSRange rangeForSelection;
    if (rangeOfParagraphsInSelectedText.count == 1 && rangeOfCurrentParagraph.length == 0 && isInFormatList) {
        rangeForSelection = NSMakeRange(rangeOfCurrentParagraph.location + formatListString.length, 0);
    } else {
        if (initialSelectedRange.length == 0) {
            rangeForSelection = NSMakeRange(initialSelectedRange.location + rangeOffset, 0);
        } else {
            NSRange fullRange = [self fullRangeFromArrayOfParagraphRanges:rangeOfParagraphsInSelectedText];
            rangeForSelection = NSMakeRange(fullRange.location, fullRange.length + rangeOffset - (mustDecreaseIndentAfterRemovingFormatList ? 0 : 1));
        }
    }
    
    if (mustDecreaseIndentAfterRemovingFormatList) {
        /// Remove the extra indentation added by the bullet
        [self userSelectedParagraphIndentation:ParagraphIndentationDecrease];
    }
    
    [self setSelectedRange:rangeForSelection];
    [self setNeedsUpdateLayout:YES];
    
    if (!self.isInTextDidChange) {
        [self sendDelegateTVChanged];
    }
}

/// Modified from https://stackoverflow.com/a/4833778/3938401
- (void)changeFontTo:(NSFont *)font {
    NSTextStorage *textStorage = [self textStorage];
    [textStorage beginEditing];
    [textStorage enumerateAttributesInRange:NSMakeRange(0, textStorage.length)
                                    options:0
                                 usingBlock:^(NSDictionary *attributesDictionary, NSRange range, BOOL *stop) {
        NSFont *currFont = [attributesDictionary objectForKey:NSFontAttributeName];
        
        if (currFont) {
            NSFont *fontToChangeTo = [font fontWithBoldTrait:currFont.isBold andItalicTrait:currFont.isItalic];
            
            if (fontToChangeTo) {
                [textStorage removeAttribute:NSFontAttributeName range:range];
                [textStorage addAttribute:NSFontAttributeName value:fontToChangeTo range:range];
            }
        }
    }];
    
    [textStorage endEditing];
}

#pragma mark - Private Methods -

- (void)setNeedsUpdateLayout:(BOOL)needsUpdateLayout {
    /// Should set the needsDisplay to YES for letting the view redraw format list layout
    /// in NSLayoutManager's subclass.
    [self setNeedsDisplay:needsUpdateLayout];
}

- (void)performBlockWithRestoringScrollLocation:(void (^)(void))block {
    /// Have no idea why the RichTextEditor is programmatically created,
    /// its scrollView will automatically scroll anytime these following methods of NSTextStorage called
    /// [-deleteCharactersInRange:]
    /// [-insertAttributedString:atIndex:]
    /// [-addAttribute:value:range:]
    /// Therefor, have to trick by restoring the current scrolling position after above methods called.
    NSScrollView *scrollView = self.enclosingScrollView;
    NSPoint currentScrollPosition = [[scrollView contentView] bounds].origin;
    
    block();
    
    NSPoint scrollPosition = [[scrollView contentView] bounds].origin;
    
    if ((currentScrollPosition.x != scrollPosition.x) || (currentScrollPosition.y != scrollPosition.y)) {
        NSRect scrollFrame = [scrollView bounds];
        NSRect documentFrame = [[scrollView documentView] frame];
        CGFloat deltaX = NSMinX(scrollFrame) - NSMinX(documentFrame);
        CGFloat deltaY = NSMinY(scrollFrame) - NSMinY(documentFrame);
        NSPoint location = NSMakePoint(currentScrollPosition.x + deltaX, currentScrollPosition.y + deltaY);
        
        [[scrollView documentView] scrollPoint:location];
    }
}

- (void)enumarateThroughParagraphsInRange:(NSRange)range withBlock:(void (^)(NSRange paragraphRange))block {
    NSArray *rangeOfParagraphsInSelectedText = [self.attributedString rangeOfParagraphsFromTextRange:range];
    
    for (int i = 0; i < rangeOfParagraphsInSelectedText.count; i++) {
        NSValue *value = rangeOfParagraphsInSelectedText[i];
        NSRange paragraphRange = [value rangeValue];
        block(paragraphRange);
    }
    
    rangeOfParagraphsInSelectedText = [self.attributedString rangeOfParagraphsFromTextRange:([self selectedRange].length < range.length) ? range : [self selectedRange]];
    NSRange fullRange = [self fullRangeFromArrayOfParagraphRanges:rangeOfParagraphsInSelectedText];
    
    if (fullRange.location + fullRange.length > [self.attributedString length]) {
        fullRange.length = 0;
        fullRange.location = [self.attributedString length] - 1;
    } else {
        fullRange = NSMakeRange(fullRange.location, fullRange.length - 1);
    }
    
    [self setSelectedRange:fullRange];
}

- (NSRange)fullRangeFromArrayOfParagraphRanges:(NSArray *)paragraphRanges {
    if (!paragraphRanges.count) {
        return NSMakeRange(0, 0);
    }
    
    NSRange firstRange = [paragraphRanges[0] rangeValue];
    NSRange lastRange = [[paragraphRanges lastObject] rangeValue];
    
    return NSMakeRange(firstRange.location, lastRange.location + lastRange.length - firstRange.location);
}

- (NSFont *)fontAtIndex:(NSInteger)index {
    return [[self dictionaryAtIndex:index] objectForKey:NSFontAttributeName];
}

- (BOOL)hasText {
    return self.string.length > 0;
}

- (NSDictionary *)dictionaryAtIndex:(NSInteger)index {
    if (![self hasText] || index == self.string.length) {
        return [self typingAttributes]; // end of string, use whatever we're currently using
    } else {
        return [self.attributedString attributesAtIndex:index effectiveRange:nil];
    }
}

- (void)updateTypingAttributes {
    /// http://stackoverflow.com/questions/11835497/nstextview-not-applying-attributes-to-newly-inserted-text
    NSArray *selectedRanges = [self selectedRanges];
    
    if (selectedRanges && selectedRanges.count > 0 && [self hasText]) {
        NSValue *firstSelectionRangeValue = selectedRanges[0];
        
        if (firstSelectionRangeValue) {
            NSRange firstCharacterOfSelectedRange = [firstSelectionRangeValue rangeValue];
            
            if (firstCharacterOfSelectedRange.location >= [self textStorage].length) {
                firstCharacterOfSelectedRange.location = [self textStorage].length - 1;
            }
            
            NSDictionary *attributesDictionary = [[self textStorage] attributesAtIndex:firstCharacterOfSelectedRange.location effectiveRange: NULL];
            
            [self setTypingAttributes:attributesDictionary];
        }
    }
}

- (void)applyAttributeToTypingAttribute:(id)attribute forKey:(NSString *)key {
    NSMutableDictionary *dictionary = [[self typingAttributes] mutableCopy];
    [dictionary setObject:attribute forKey:key];
    [self setTypingAttributes:dictionary];
}

- (void)applyAttributes:(id)attribute forKey:(NSString *)key atRange:(NSRange)range {
    /// If any text selected apply attributes to text
    if (range.length > 0) {
        /// Workaround for when there is only one paragraph,
        /// sometimes the attributedString is actually longer by one then the displayed text,
        /// and this results in not being able to set to lef align anymore.
        if (range.length == [self textStorage].length - 1 && range.length == self.string.length) {
            ++range.length;
        }
        
        [[self textStorage] addAttributes:[NSDictionary dictionaryWithObject:attribute forKey:key] range:range];
        
        /// Have to update typing attributes because the selection won't change after these attributes have changed.
        [self updateTypingAttributes];
    } else {
        /// If no text is selected apply attributes to typingAttribute
        self.typingAttributesInProgress = YES;
        [self applyAttributeToTypingAttribute:attribute forKey:key];
    }
}

- (void)removeAttributeForKey:(NSString *)key atRange:(NSRange)range {
    NSRange initialRange = [self selectedRange];
    [[self textStorage] removeAttribute:key range:range];
    [self setSelectedRange:initialRange];
}

- (void)removeAttributeForKeyFromSelectedRange:(NSString *)key {
    [self removeAttributeForKey:key atRange:[self selectedRange]];
}

- (void)applyAttributesToSelectedRange:(id)attribute forKey:(NSString *)key {
    [self applyAttributes:attribute forKey:key atRange:[self selectedRange]];
}

- (void)applyFontAttributesToSelectedRangeWithBoldTrait:(NSNumber *)isBold italicTrait:(NSNumber *)isItalic fontName:(NSString *)fontName fontSize:(NSNumber *)fontSize {
    [self applyFontAttributesWithBoldTrait:isBold italicTrait:isItalic fontName:fontName fontSize:fontSize toTextAtRange:[self selectedRange]];
}

- (void)applyFontAttributesWithBoldTrait:(NSNumber *)isBold italicTrait:(NSNumber *)isItalic fontName:(NSString *)fontName fontSize:(NSNumber *)fontSize toTextAtRange:(NSRange)range {
    /// If any text selected apply attributes to text
    if (range.length > 0) {
        [[self textStorage] beginEditing];
        [[self textStorage] enumerateAttributesInRange:range
                                               options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                            usingBlock:^(NSDictionary *dictionary, NSRange range, BOOL *stop) {
            
            NSFont *newFont = [self fontwithBoldTrait:isBold
                                          italicTrait:isItalic
                                             fontName:fontName
                                             fontSize:fontSize
                                       fromDictionary:dictionary];
            
            if (newFont) {
                [[self textStorage] addAttributes:[NSDictionary dictionaryWithObject:newFont forKey:NSFontAttributeName] range:range];
            }
        }];
        [[self textStorage] endEditing];
        [self setSelectedRange:range];
        [self updateTypingAttributes];
    } else {
        /// If no text is selected apply attributes to typingAttribute
        self.typingAttributesInProgress = YES;
        NSFont *newFont = [self fontwithBoldTrait:isBold
                                      italicTrait:isItalic
                                         fontName:fontName
                                         fontSize:fontSize
                                   fromDictionary:[self typingAttributes]];
        if (newFont) {
            [self applyAttributeToTypingAttribute:newFont forKey:NSFontAttributeName];
        }
    }
}

- (BOOL)hasSelection {
    return [self selectedRange].length > 0;
}

/// By default, if this function is called with nothing selected, it will resize all text.
- (void)changeFontSizeWithOperation:(CGFloat(^)(CGFloat currFontSize))operation {
    [[self textStorage] beginEditing];
    NSRange range = [self selectedRange];
    
    if (range.length == 0) {
        range = NSMakeRange(0, [self textStorage].length);
    }
    
    [[self textStorage] enumerateAttributesInRange:range
                                           options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                        usingBlock:^(NSDictionary *dictionary, NSRange range, BOOL *stop) {
        /// Get current font size
        NSFont *currFont = [dictionary objectForKey:NSFontAttributeName];
        
        if (currFont) {
            CGFloat currFontSize = currFont.pointSize;
            CGFloat nextFontSize = operation(currFontSize);
            
            if ((currFontSize < nextFontSize && nextFontSize <= self.maxFontSize) || // sizing up
                (currFontSize > nextFontSize && self.minFontSize <= nextFontSize)) { // sizing down
                
                NSFont *newFont = [self fontwithBoldTrait:[NSNumber numberWithBool:[currFont isBold]]
                                              italicTrait:[NSNumber numberWithBool:[currFont isItalic]]
                                                 fontName:currFont.fontName
                                                 fontSize:[NSNumber numberWithFloat:nextFontSize]
                                           fromDictionary:dictionary];
                
                if (newFont) {
                    [[self textStorage] addAttributes:[NSDictionary dictionaryWithObject:newFont forKey:NSFontAttributeName] range:range];
                }
            }
        }
    }];
    
    [[self textStorage] endEditing];
    [self updateTypingAttributes];
}

- (void)decreaseFontSize {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeFontSize];
    
    if ([self selectedRange].length == 0) {
        NSMutableDictionary *typingAttributes = [[self typingAttributes] mutableCopy];
        NSFont *font = [typingAttributes valueForKey:NSFontAttributeName];
        CGFloat nextFontSize = font.pointSize - self.fontSizeChangeAmount;
        
        if (nextFontSize < self.minFontSize)
            nextFontSize = self.minFontSize;
        
        NSFont *nextFont = [[NSFontManager sharedFontManager] convertFont:font toSize:nextFontSize];
        [typingAttributes setValue:nextFont forKey:NSFontAttributeName];
        
        [self setTypingAttributes:typingAttributes];
    } else {
        [self changeFontSizeWithOperation:^CGFloat (CGFloat currFontSize) {
            return currFontSize - self.fontSizeChangeAmount;
        }];
        
        [self sendDelegateTVChanged]; // only send if the actual text changes -- if no text selected, no text has actually changed
    }
}

- (void)increaseFontSize {
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeFontSize];
    
    if ([self selectedRange].length == 0) {
        NSMutableDictionary *typingAttributes = [[self typingAttributes] mutableCopy];
        NSFont *font = [typingAttributes valueForKey:NSFontAttributeName];
        CGFloat nextFontSize = font.pointSize + self.fontSizeChangeAmount;
        if (nextFontSize > self.maxFontSize) {
            nextFontSize = self.maxFontSize;
        }
        NSFont *nextFont = [[NSFontManager sharedFontManager] convertFont:font toSize:nextFontSize];
        [typingAttributes setValue:nextFont forKey:NSFontAttributeName];
        
        [self setTypingAttributes:typingAttributes];
    } else {
        [self changeFontSizeWithOperation:^CGFloat (CGFloat currFontSize) {
            return currFontSize + self.fontSizeChangeAmount;
        }];
        /// Only send if the actual text changes -- if no text selected, no text has actually changed
        [self sendDelegateTVChanged];
    }
}

/// TODO: Fix this function. You can't create a font that isn't bold from a dictionary that has a bold attribute currently, since if you send isBold 0 [nil], it'll use the dictionary, which is bold!
/// In other words, this function has logical errors
/// Returns a font with given attributes. For any missing parameter takes the attribute from a given dictionary
- (NSFont *)fontwithBoldTrait:(NSNumber *)isBold italicTrait:(NSNumber *)isItalic fontName:(NSString *)fontName fontSize:(NSNumber *)fontSize fromDictionary:(NSDictionary *)dictionary {
    NSFont *newFont = nil;
    NSFont *font = [dictionary objectForKey:NSFontAttributeName];
    BOOL newBold = (isBold) ? isBold.intValue : [font isBold];
    BOOL newItalic = (isItalic) ? isItalic.intValue : [font isItalic];
    CGFloat newFontSize = (fontSize) ? fontSize.floatValue : font.pointSize;
    
    if (fontName) {
        newFont = [NSFont fontWithName:fontName size:newFontSize boldTrait:newBold italicTrait:newItalic];
    } else {
        newFont = [font fontWithBoldTrait:newBold italicTrait:newItalic andSize:newFontSize];
    }
    
    return newFont;
}

/**
 * Does not allow cursor to be right beside the bullet point. This method also does not allow selection of the bullet point itself.
 * It uses the previousCursorPosition property to save the previous cursor location.
 *
 * @param beginRange The beginning position of the paragraph
 * @param previousRange The previous cursor position before the new change. Only used for keyboard change events
 * @param currentRange The current cursor position after the new change
 * @param isMouseClick A boolean to check whether the requested change is a mouse event or a keyboard event
 */
- (NSRange)adjustSelectedRangeFormatListWithBeginRange:(NSRange)beginRange previousRange:(NSRange)previousRange currentRange:(NSRange)currentRange isMouseClick:(BOOL)isMouseClick {
    NSUInteger previous = self.previousCursorPosition;
    NSUInteger begin = beginRange.location;
    NSUInteger current = currentRange.location;
    NSRange finalRange = currentRange;
    
    if (self.justDeletedBackward) {
        return finalRange;
    }
    
    NSString *bulletString = [RTELayoutManager kBulletString];
    NSString *numberingString = [RTELayoutManager kNumberingString];
    BOOL inBulletedList = [[self.string substringFromIndex:begin] hasPrefix:bulletString];
    BOOL inNumberedList = [[self.string substringFromIndex:begin] hasPrefix:numberingString];
    BOOL hasFormatListInFront = inBulletedList || inNumberedList;
    
    if (hasFormatListInFront) {
        if (!isMouseClick && (current == begin + 1)) {
            /// Select bullet point when using keyboard arrow keys
            if (previousRange.location > current) {
                finalRange = NSMakeRange(begin, currentRange.length + 1);
            } else if (previousRange.location < current) {
                finalRange = NSMakeRange(current + 1, currentRange.length - 1);
            }
        } else {
            if ((current == begin && (previous > current || previous < current)) ||
                (current == (begin + 1) && (previous < current || current == previous))) {
                /// Cursor moved from in bullet to front of bullet
                finalRange = currentRange.length >= 1 ? NSMakeRange(begin, finalRange.length + 1) : NSMakeRange(begin + 2, 0);
            } else if (current == (begin + 1) && previous > current) {
                /// Cursor moved from in bullet to beside of bullet
                BOOL isNewLocationValid = (begin - 1) > [self.string length] ? NO : YES;
                finalRange = currentRange.length >= 1 ? NSMakeRange(begin, finalRange.length + 1) : NSMakeRange(isNewLocationValid ? begin - 1 : begin + 2, 0);
            } else if ((current == begin) && (begin == previous) && isMouseClick) {
                finalRange = currentRange.length >= 1 ? NSMakeRange(begin, finalRange.length + 1) : NSMakeRange(begin + 2, 0);
            }
        }
    }
    
    if (currentRange.location > self.string.length || currentRange.location + currentRange.length > self.string.length) {
        /// Select the very end of the string.
        /// there was a crash report that had an out of range error. Couldn't replicate, so trying
        /// to avoid future crashes.
        return NSMakeRange(self.string.length, 0);
    }
    
    NSRange endingStringRange = [[self.string substringWithRange:currentRange] rangeOfString:[NSString stringWithFormat:@"\n%@", inBulletedList ? bulletString : numberingString] options:NSBackwardsSearch];
    NSUInteger currentRangeAddedProperties = currentRange.location + currentRange.length;
    NSUInteger previousRangeAddedProperties = previousRange.location + previousRange.length;
    BOOL hasFormatListAtTheEnd = (endingStringRange.length + endingStringRange.location + currentRange.location) == currentRangeAddedProperties;
    
    if (hasFormatListAtTheEnd) {
        if (isMouseClick) {
            if (previousRange.length > current) {
                finalRange = NSMakeRange(current, currentRange.length + 1);
            } else if (previousRange.length < current) {
                finalRange = NSMakeRange(current, currentRange.length - 1);
            }
        } else {
            if (previousRangeAddedProperties < currentRangeAddedProperties) {
                finalRange = NSMakeRange(current, currentRange.length + 1);
            } else if (previousRangeAddedProperties > currentRangeAddedProperties) {
                finalRange = NSMakeRange(current, currentRange.length - 1);
            }
        }
    }
    
    self.previousCursorPosition = finalRange.location;
    
    return finalRange;
}

- (void)applyListIfApplicableForType:(RichTextEditorPreviewChange)formatType {
    if ((formatType != RichTextEditorPreviewChangeBulletedList) && (formatType != RichTextEditorPreviewChangeNumberingList)) return;
    
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:[self selectedRange]];
    
    if (rangeOfCurrentParagraph.location == 0) {
        return; /// there isn't a previous paragraph, so forget it. The user isn't in a bulleted list.
    }
    
    NSString *formatListString = (formatType == RichTextEditorPreviewChangeBulletedList) ? [RTELayoutManager kBulletString] : [RTELayoutManager kNumberingString];
    NSRange rangeOfPreviousParagraph = [self.attributedString firstParagraphRangeFromTextRange:NSMakeRange(rangeOfCurrentParagraph.location - 1, 0)];
    //self.replacementString
    BOOL previousParagraphHasFormatList = [[self.string substringFromIndex:rangeOfPreviousParagraph.location] hasPrefix:formatListString];
    BOOL isInFormatList = self.inBulletedList || self.inNumberedList;
    
    if (!isInFormatList) {
        /// Fixes issue with backspacing into bullet list adding a bullet
        // NSLog(@"[RTE] NOT in a bulleted list.");
        BOOL currentParagraphHasFormatList = [[self.string substringFromIndex:rangeOfCurrentParagraph.location] hasPrefix:formatListString];
        BOOL isCurrParaBlank = [[self.string substringWithRange:rangeOfCurrentParagraph] isEqualToString:@""];
        /// If we don't check to see if the current paragraph is blank, bad bugs happen with
        /// the current paragraph where the selected range doesn't let the user type O_o
        if (previousParagraphHasFormatList && !currentParagraphHasFormatList && isCurrParaBlank) {
            /// Fix the indentation. Here is the use case for this code:
            /*
             ---
             • bullet
             
             |
             ---
             Where | is the cursor on a blank line. User hits backspace. Without fixing the
             indentation, the cursor ends up indented at the same indentation as the bullet.
             */
            NSDictionary *dictionary = [self dictionaryAtIndex:rangeOfCurrentParagraph.location];
            NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
            paragraphStyle.firstLineHeadIndent = 0;
            paragraphStyle.headIndent = 0;
            [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:rangeOfCurrentParagraph];
            [self setIndentationWithAttributes:dictionary paragraphStyle:paragraphStyle atRange:rangeOfCurrentParagraph];
        }
        
        return;
    }
    
    if (rangeOfCurrentParagraph.length != 0 && !(previousParagraphHasFormatList && [self.latestReplacementString isEqualToString:@"\n"])) {
        return;
    }
    
    if (!self.justDeletedBackward && [[self.string substringFromIndex:rangeOfPreviousParagraph.location] hasPrefix:formatListString]) {
        [self userSelectedFormatListWithType:formatType];
    }
}

- (void)removeFormatListIndentation:(NSRange)firstParagraphRange {
    NSRange rangeOfParagraph = [self.attributedString firstParagraphRangeFromTextRange:firstParagraphRange];
    NSDictionary *dictionary = [self dictionaryAtIndex:rangeOfParagraph.location];
    NSMutableParagraphStyle *paragraphStyle = [[dictionary objectForKey:NSParagraphStyleAttributeName] mutableCopy];
    paragraphStyle.firstLineHeadIndent = 0;
    paragraphStyle.headIndent = 0;
    
    [self applyAttributes:paragraphStyle forKey:NSParagraphStyleAttributeName atRange:rangeOfParagraph];
    [self setIndentationWithAttributes:dictionary paragraphStyle:paragraphStyle atRange:firstParagraphRange];
}

- (void)deleteFormatListWhenApplicable:(RichTextEditorPreviewChange)formatType {
    if ((formatType != RichTextEditorPreviewChangeBulletedList) && (formatType != RichTextEditorPreviewChangeNumberingList)) return;
    
    NSRange range = [self selectedRange];
    /// TODO: Clean up this code since a lot of it is "repeated"
    NSString *formatListString = (formatType == RichTextEditorPreviewChangeBulletedList) ? [RTELayoutManager kBulletString] : [RTELayoutManager kNumberingString];
    
    if (range.location > 0) {
        NSString *checkString = formatListString;
        if (checkString.length > 1) {
            // chop off last letter and use that
            checkString = [checkString substringToIndex:checkString.length - 1];
        }
        //else return;
        NSUInteger checkStringLength = [checkString length];
        if (![self.string isEqualToString:formatListString]) {
            if (((int)(range.location - checkStringLength) >= 0 && [[self.string substringFromIndex:range.location - checkStringLength] hasPrefix:checkString])) {
                [self sendDelegatePreviewChangeOfType:formatType];
                // NSLog(@"[RTE] Getting rid of a bullet due to backspace while in empty bullet paragraph.");
                /// Get rid of bullet string
                [[self textStorage] deleteCharactersInRange:NSMakeRange(range.location - checkStringLength, checkStringLength)];
                NSRange newRange = NSMakeRange(range.location - checkStringLength, 0);
                [self setSelectedRange:newRange];
                
                /// Get rid of bullet indentation
                [self removeFormatListIndentation:newRange];
            } else {
                /// User may be needing to get out of a bulleted list due to hitting enter (return)
                NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:[self selectedRange]];
                NSString *currentParagraphString = [self.string substringWithRange:rangeOfCurrentParagraph];
                NSInteger prevParaLocation = rangeOfCurrentParagraph.location - 1;
                /// [currentParagraphString isEqualToString:formatListString] ==> "is the current paragraph an empty bulleted list item?"
                if (prevParaLocation >= 0 && [currentParagraphString isEqualToString:formatListString]) {
                    NSRange rangeOfPreviousParagraph = [self.attributedString firstParagraphRangeFromTextRange:NSMakeRange(rangeOfCurrentParagraph.location - 1, 0)];
                    /// If the following if statement is true, the user hit enter on a blank bullet list
                    /// Basically, there is now a bullet ' ' \n bullet ' ' that we need to delete (' ' == space)
                    /// Since it gets here AFTER it adds a new bullet
                    if ([[self.string substringWithRange:rangeOfPreviousParagraph] hasSuffix:formatListString]) {
                        [self sendDelegatePreviewChangeOfType:formatType];
                        // NSLog(@"[RTE] Getting rid of bullets due to user hitting enter.");
                        NSRange rangeToDelete = NSMakeRange(rangeOfPreviousParagraph.location, rangeOfPreviousParagraph.length + rangeOfCurrentParagraph.length + 1);
                        [[self textStorage] deleteCharactersInRange:rangeToDelete];
                        NSRange newRange = NSMakeRange(rangeOfPreviousParagraph.location, 0);
                        [self setSelectedRange:newRange];
                        /// Get rid of bullet indentation
                        [self removeFormatListIndentation:newRange];
                    }
                }
            }
        }
    }
}

- (void)deleteMultipleFormatListsIfApplicable:(RichTextEditorPreviewChange)formatType {
    if ((formatType != RichTextEditorPreviewChangeBulletedList) && (formatType != RichTextEditorPreviewChangeNumberingList)) return;
    
    NSRange selectedRange = [self selectedRange];
    NSString *formatListString = (formatType == RichTextEditorPreviewChangeBulletedList) ? [RTELayoutManager kBulletString] : [RTELayoutManager kNumberingString];
    NSRange initialSelectedRange = selectedRange;
    NSRange rangeOfCurrentParagraph = [self.attributedString firstParagraphRangeFromTextRange:selectedRange];
    NSArray *rangeOfParagraphsInSelectedText = [self.attributedString rangeOfParagraphsFromTextRange:selectedRange];
    
    NSString *bulletString = [RTELayoutManager kBulletString];
    NSString *numberingString = [RTELayoutManager kNumberingString];
    NSString *noneFormatString = @"";
    
    __block NSInteger rangeOffset = 0;
    __block BOOL mustDecreaseIndentAfterRemovingFormatList = NO;
    __block BOOL isInFormatList = NO;
    __block NSMutableArray<NSString *> *usedFormats = [[NSMutableArray alloc] init];
    
    [self.attributedString enumarateParagraphsInRange:[self selectedRange] withBlock:^(NSRange paragraphRange) {
        NSRange range = NSMakeRange(paragraphRange.location, paragraphRange.length);
        
        if ([[self.string substringFromIndex:range.location] hasPrefix:bulletString]) {
            if (![usedFormats containsObject:bulletString]) {
                [usedFormats addObject:bulletString];
            }
        } else if ([[self.string substringFromIndex:range.location] hasPrefix:numberingString]) {
            if (![usedFormats containsObject:numberingString]) {
                [usedFormats addObject:numberingString];
            }
        } else {
            if (![usedFormats containsObject:noneFormatString]) {
                [usedFormats addObject:noneFormatString];
            }
        }
    }];
    
    if (usedFormats.count > 1) {
        [self enumarateThroughParagraphsInRange:[self selectedRange] withBlock:^(NSRange paragraphRange) {
            NSRange range = NSMakeRange(paragraphRange.location + rangeOffset, paragraphRange.length);
            
            if ([[self.string substringFromIndex:range.location] hasPrefix:bulletString]) {
                range = NSMakeRange(range.location, range.length - bulletString.length);
                
                [[self textStorage] deleteCharactersInRange:NSMakeRange(range.location, bulletString.length)];
                
                rangeOffset = rangeOffset - bulletString.length;
                mustDecreaseIndentAfterRemovingFormatList = YES;
            } else if ([[self.string substringFromIndex:range.location] hasPrefix:numberingString]) {
                range = NSMakeRange(range.location, range.length - numberingString.length);
                
                [[self textStorage] deleteCharactersInRange:NSMakeRange(range.location, numberingString.length)];
                
                rangeOffset = rangeOffset - numberingString.length;
                mustDecreaseIndentAfterRemovingFormatList = YES;
            }
        }];
        
        NSRange rangeForSelection;
        if (rangeOfParagraphsInSelectedText.count == 1 && rangeOfCurrentParagraph.length == 0 && isInFormatList) {
            rangeForSelection = NSMakeRange(rangeOfCurrentParagraph.location + formatListString.length, 0);
        } else {
            if (initialSelectedRange.length == 0) {
                rangeForSelection = NSMakeRange(initialSelectedRange.location + rangeOffset, 0);
            } else {
                NSRange fullRange = [self fullRangeFromArrayOfParagraphRanges:rangeOfParagraphsInSelectedText];
                rangeForSelection = NSMakeRange(fullRange.location, fullRange.length + rangeOffset - (mustDecreaseIndentAfterRemovingFormatList ? 0 : 1));
            }
        }
        
        [self setSelectedRange:rangeForSelection];
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    _lastSingleKeyPressed = 0;
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeMouseDown];
    [super mouseDown:theEvent];
}

- (void)mouseDragged:(NSEvent *)event {
    _lastSingleKeyPressed = 0;
    [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeMouseDragged];
    [super mouseDragged:event];
}

+ (NSString *)convertPreviewChangeTypeToString:(RichTextEditorPreviewChange)changeType withNonSpecialChangeText:(BOOL)shouldReturnStringForNonSpecialType {
    switch (changeType) {
        case RichTextEditorPreviewChangeBold:
            return NSLocalizedString(@"Bold", @"");
        case RichTextEditorPreviewChangeCut:
            return NSLocalizedString(@"Cut", @"");
        case RichTextEditorPreviewChangePaste:
            return NSLocalizedString(@"Paste", @"");
        case RichTextEditorPreviewChangeBulletedList:
            return NSLocalizedString(@"Bulleted List", @"");
        case RichTextEditorPreviewChangeItalic:
            return NSLocalizedString(@"Italic", @"");
        case RichTextEditorPreviewChangeFontResize:
        case RichTextEditorPreviewChangeFontSize:
            return NSLocalizedString(@"Font Resize", @"");
        case RichTextEditorPreviewChangeFontColor:
            return NSLocalizedString(@"Font Color", @"");
        case RichTextEditorPreviewChangeHighlight:
            return NSLocalizedString(@"Text Highlight", @"");
        case RichTextEditorPreviewChangeUnderline:
            return NSLocalizedString(@"Underline", @"");
        case RichTextEditorPreviewChangeIndentDecrease:
        case RichTextEditorPreviewChangeIndentIncrease:
            return NSLocalizedString(@"Text Indent", @"");
        case RichTextEditorPreviewChangeKeyDown:
            if (shouldReturnStringForNonSpecialType)
                return NSLocalizedString(@"Key Down", @"");
            break;
        case RichTextEditorPreviewChangeEnter:
            if (shouldReturnStringForNonSpecialType)
                return NSLocalizedString(@"Enter [Return] Key", @"");
            break;
        case RichTextEditorPreviewChangeSpace:
            if (shouldReturnStringForNonSpecialType)
                return NSLocalizedString(@"Space", @"");
            break;
        case RichTextEditorPreviewChangeDelete:
            if (shouldReturnStringForNonSpecialType)
                return NSLocalizedString(@"Delete", @"");
            break;
        case RichTextEditorPreviewChangeArrowKey:
            if (shouldReturnStringForNonSpecialType)
                return NSLocalizedString(@"Arrow Key Movement", @"");
            break;
        case RichTextEditorPreviewChangeMouseDown:
            if (shouldReturnStringForNonSpecialType)
                return NSLocalizedString(@"Mouse Down", @"");
            break;
        case RichTextEditorPreviewChangeFindReplace:
            return NSLocalizedString(@"Find & Replace", @"");
        default:
            break;
    }
    return @"";
}

#pragma mark - Keyboard Shortcuts

/// http://stackoverflow.com/questions/970707/cocoa-keyboard-shortcuts-in-dialog-without-an-edit-menu
- (void)keyDown:(NSEvent *)event {
    NSString *key = event.charactersIgnoringModifiers;
    
    if (key.length > 0) {
        NSUInteger enabledShortcuts = RichTextEditorShortcutAll;
        
        if (self.rteDataSource && [self.rteDataSource respondsToSelector:@selector(enabledKeyboardShortcuts)]) {
            enabledShortcuts = [self.rteDataSource enabledKeyboardShortcuts];
        }
        
        unichar keyChar = 0;
        bool shiftKeyDown = event.modifierFlags & NSEventModifierFlagShift;
        bool commandKeyDown = event.modifierFlags & NSEventModifierFlagCommand;
        keyChar = [key characterAtIndex:0];
        _lastSingleKeyPressed = keyChar;
        
        if (keyChar == NSLeftArrowFunctionKey || keyChar == NSRightArrowFunctionKey ||
            keyChar == NSUpArrowFunctionKey || keyChar == NSDownArrowFunctionKey) {
            [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeArrowKey];
            [super keyDown:event];
        } else if ((keyChar == 'b' || keyChar == 'B') && commandKeyDown && !shiftKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutBold)) {
            [self userSelectedBold];
        } else if ((keyChar == 'i' || keyChar == 'I') && commandKeyDown && !shiftKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutItalic)) {
            [self userSelectedItalic];
        } else if ((keyChar == 'u' || keyChar == 'U') && commandKeyDown && !shiftKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutUnderline)) {
            [self userSelectedUnderline];
        } else if (keyChar == '>' && shiftKeyDown && commandKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutIncreaseFontSize)) {
            [self increaseFontSize];
        } else if (keyChar == '<' && shiftKeyDown && commandKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutDecreaseFontSize)) {
            [self decreaseFontSize];
        } else if (keyChar == 'L' && shiftKeyDown && commandKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutBulletedList)) {
            [self userSelectedBulletedList];
        } else if (keyChar == 'N' && shiftKeyDown && commandKeyDown && [self isInBulletedList] &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutLeaveBulletedList)) {
            [self userSelectedBulletedList];
        } else if (keyChar == 'T' && shiftKeyDown && commandKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutDecreaseIndent)) {
            [self userSelectedDecreaseIndent];
        } else if (keyChar == 't' && commandKeyDown && !shiftKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutIncreaseIndent)) {
            [self userSelectedIncreaseIndent];
        } else if (self.tabKeyAlwaysIndentsOutdents && keyChar == '\t' && !commandKeyDown && !shiftKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutIncreaseIndent)) {
            [self userSelectedIncreaseIndent];
        } else if (self.tabKeyAlwaysIndentsOutdents && (keyChar == '\t' || keyChar == 25) && !commandKeyDown && shiftKeyDown &&
                   (enabledShortcuts == RichTextEditorShortcutAll || enabledShortcuts & RichTextEditorShortcutIncreaseIndent)) {
            [self userSelectedDecreaseIndent];
        } else if (!([self.rteDelegate respondsToSelector:@selector(richTextEditor:keyDownEvent:)] && [self.rteDelegate richTextEditor:self keyDownEvent:event])) {
            [self sendDelegatePreviewChangeOfType:RichTextEditorPreviewChangeKeyDown];
            [super keyDown:event];
        }
    } else {
        [super keyDown:event];
    }
}

@end
