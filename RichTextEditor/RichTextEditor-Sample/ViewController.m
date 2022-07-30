//
//  ViewController.m
//  macOSRTESample
//
//  Created by Deadpikle on 3/28/18.
//  Copyright © 2018 Pikle Productions. All rights reserved.
//

#import "ViewController.h"

#import "FontManager.h"

#import "EditHyperLinkToolbar.h"

@interface NSImage (Tint)

- (NSImage *)imageTintedWithColor:(NSColor *)tint;

@end

@implementation NSImage (Tint)

// https://stackoverflow.com/a/16138027/3938401
- (NSImage *)imageTintedWithColor:(NSColor *)tint {
    NSImage *image = [self copy];
    if (tint) {
        [image lockFocus];
        [tint set];
        NSRect imageRect = {NSZeroPoint, [image size]};
        NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        [image unlockFocus];
    }
    return image;
}

@end

@interface ViewController () <RichTextEditorDelegate, NSPopoverDelegate, EditToolbarDelegate> {
    NSPopover *_toolbarPopover;
}

@property (weak) IBOutlet NSButton *boldButton;
@property (weak) IBOutlet NSButton *italicButton;
@property (weak) IBOutlet NSButton *underlineButton;
@property (weak) IBOutlet NSButton *strikethroughButton;
@property (weak) IBOutlet NSButton *bulletedListButton;
@property (weak) IBOutlet NSButton *orderedListButton;
@property (weak) IBOutlet NSButton *decreaseIndentButton;
@property (weak) IBOutlet NSButton *increaseIndentButton;
@property (weak) IBOutlet NSButton *fontNameButton;
@property (weak) IBOutlet NSButton *decreaseFontSizeButton;
@property (weak) IBOutlet NSButton *increaseFontSizeButton;
@property (weak) IBOutlet NSButton *fontSizeButton;
@property (weak) IBOutlet NSButton *hyperlinkButton;
@property (weak) IBOutlet NSColorWell *colorPickerButton;
@property (weak) IBOutlet NSButton *tabKeyAlwaysIndentsButton;

@property (weak) IBOutlet NSView *inputView;
@property (strong) IBOutlet RichTextEditor *textField;
@property (weak) IBOutlet NSView *richTextView;
@property (strong) IBOutlet RichTextEditor *textView;

@property (nonatomic, strong, nullable) NSURL *hyperlink;

@end

@implementation ViewController

// MARK: - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self configUI];
    [self.inputView setWantsLayer:YES];
    [[self.inputView layer] setCornerRadius:6];
    [[self.inputView layer] setBackgroundColor:[[NSColor colorWithSRGBRed:(221.0 / 255) green:(211.0 / 255) blue:(247.0 / 255) alpha:1] CGColor]];
    [self.textField useSingleLineMode];
    [self.textField setTextContainerInset:NSMakeSize(15, 6)];
    self.textField.rteDelegate = self;
    
    [self.richTextView setWantsLayer:YES];
    [[self.richTextView layer] setCornerRadius:6];
    [[self.richTextView layer] setBackgroundColor:[[NSColor colorWithSRGBRed:(252.0 / 255) green:(223.0 / 255) blue:(193.0 / 255) alpha:1] CGColor]];
    [self.textView setTextContainerInset:NSMakeSize(15, 15)];
    self.textView.rteDelegate = self;
}

- (void)configUI {
    [self configTextEditor];
    [self setFontNameButtonFont:[NSFont systemFontOfSize:13]];
}

- (void)configTextEditor {
    NSString *text = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\
    \n\
    \n\
    Tom he made a sign to me—kind of a little noise with his mouth—and we went creeping away on our hands and knees.\n\
    When we was ten foot off Tom whispered to me, and wanted to tie Jim to the tree for fun. But I said no; he might wake and make a disturbance, and then they’d find out I warn’t in.\n\
    Then Tom said he hadn’t got candles enough, and he would slip in the kitchen and get some more. I didn’t want him to try.\n\
    I said Jim might wake up and come. But Tom wanted to resk it; so we slid in there and got three candles, and Tom laid five cents on the table for pay.\n\
    Then we got out, and I was in a sweat to get away; but nothing would do Tom but he must crawl to where Jim was, on his hands and knees, and play something on him.\n\
    I waited, and it seemed a good while, everything was so still and lonesome.\n";
    
    if (self.textField == nil) {
        NSView *parent = self.inputView;
        RichTextEditor *textEditor = [RichTextEditor initWithParent:parent frame:[parent bounds]];
        NSScrollView *scrollView = [textEditor enclosingScrollView];
        
        if (scrollView != nil) {
            NSLayoutConstraint *widthConstraint = [NSLayoutConstraint constraintWithItem:scrollView
                                                                               attribute:NSLayoutAttributeWidth
                                                                               relatedBy:NSLayoutRelationEqual
                                                                                  toItem:nil
                                                                               attribute:NSLayoutAttributeWidth
                                                                              multiplier:1
                                                                                constant:NSWidth([parent bounds])];
            
            NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:scrollView
                                                                                attribute:NSLayoutAttributeHeight
                                                                                relatedBy:NSLayoutRelationEqual
                                                                                   toItem:nil
                                                                                attribute:NSLayoutAttributeHeight
                                                                               multiplier:1
                                                                                 constant:NSHeight([parent bounds])];
            
            [scrollView setFrame:[parent bounds]];
            [scrollView addConstraint:widthConstraint];
            [scrollView addConstraint:heightConstraint];
            [parent addSubview:scrollView];
            
            [textEditor setPlaceholderAttributedString:[[NSAttributedString alloc] initWithString:@"Input some text here..."]];
            [textEditor setFont:[NSFont fontWithName:@"SavoyeLetPlain" size:18]];
            self.textField = textEditor;
        }
    }
    
    if (self.textView == nil) {
        NSView *parent = self.richTextView;
        RichTextEditor *textEditor = [RichTextEditor initWithParent:parent frame:[parent bounds]];
        NSScrollView *scrollView = [textEditor enclosingScrollView];
        
        if (scrollView != nil) {
            NSEdgeInsets contentInsets = NSEdgeInsetsZero;
            NSDictionary *metrics = @{
                @"top": @(contentInsets.top),
                @"leading": @(contentInsets.left),
                @"bottom": @(contentInsets.bottom),
                @"trailing": @(contentInsets.right)
            };
            
            [parent addSubview:scrollView];
            
            [parent addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(leading)-[scrollView]-(trailing)-|"
                                                                           options:NSLayoutFormatDirectionLeadingToTrailing
                                                                           metrics:metrics
                                                                             views:NSDictionaryOfVariableBindings(scrollView)]];
            [parent addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(top)-[scrollView]-(bottom)-|"
                                                                           options:NSLayoutFormatDirectionLeadingToTrailing
                                                                           metrics:metrics
                                                                             views:NSDictionaryOfVariableBindings(scrollView)]];
            
            [textEditor setPlaceholderAttributedString:[[NSAttributedString alloc] initWithString:@"Input text..."]];
            [textEditor setString:text];
            [textEditor setFont:[NSFont fontWithName:@"SavoyeLetPlain" size:36]];
            self.textView = textEditor;
        }
    }
}

- (void)configToolbarForTextEditor {
    if ([[self.view window] firstResponder] == self.textView) {
        [self.boldButton setEnabled:YES];
        [self.italicButton setEnabled:YES];
        [self.underlineButton setEnabled:YES];
        [self.strikethroughButton setEnabled:YES];
        [self.bulletedListButton setEnabled:YES];
        [self.orderedListButton setEnabled:YES];
        [self.decreaseIndentButton setEnabled:YES];
        [self.increaseIndentButton setEnabled:YES];
        [self.fontNameButton setEnabled:YES];
        [self.decreaseFontSizeButton setEnabled:YES];
        [self.increaseFontSizeButton setEnabled:YES];
        [self.fontSizeButton setEnabled:YES];
        [self.hyperlinkButton setEnabled:[self.hyperlinkButton isEnabled]];
    } else {
        [self.boldButton setEnabled:YES];
        [self.italicButton setEnabled:YES];
        [self.underlineButton setEnabled:YES];
        [self.strikethroughButton setEnabled:YES];
        [self.bulletedListButton setEnabled:NO];
        [self.orderedListButton setEnabled:NO];
        [self.decreaseIndentButton setEnabled:NO];
        [self.increaseIndentButton setEnabled:NO];
        [self.fontNameButton setEnabled:NO];
        [self.decreaseFontSizeButton setEnabled:NO];
        [self.increaseFontSizeButton setEnabled:NO];
        [self.fontSizeButton setEnabled:NO];
        [self.hyperlinkButton setEnabled:NO];
    }
}

- (void)setFontNameButtonFont:(NSFont *)font {
    NSFont *titleFont = [NSFont fontWithName:font.fontName size:13];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setAlignment:NSTextAlignmentCenter];
    NSDictionary *attributes = @{
        NSFontAttributeName: titleFont,
        NSForegroundColorAttributeName: [NSColor blackColor],
        NSParagraphStyleAttributeName: paragraphStyle
    };
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:titleFont.fontName attributes:attributes];
    
    [self.fontNameButton setAttributedTitle:attributedTitle];
}

// MARK: -

- (void)showFontMenuAtSender:(NSView *)sender {
    NSEvent *event = [NSApp currentEvent];
    
    if (event != NULL) {
        NSMenu *menu = [[NSMenu alloc] init];
        NSArray<NSFont *> *availableFonts = [FontManager sharedManager].availableFonts;
        
        for (NSFont *font in availableFonts) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:font.fontName action:@selector(fontMenuDidSelectItem:) keyEquivalent:@""];
            [item setRepresentedObject:font];
            [menu addItem:item];
        }
        
        [NSMenu popUpContextMenu:menu withEvent:event forView:sender];
    }
}

- (void)showFontSizeMenuAtSender:(NSView *)sender {
    NSEvent *event = [NSApp currentEvent];
    
    if (event != NULL) {
        NSMenu *menu = [[NSMenu alloc] init];
        NSArray<NSNumber *> *fontSizes = @[@(10), @(12), @(14), @(18), @(24), @(36)];
        
        for (NSNumber *fontSize in fontSizes) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@", fontSize] action:@selector(fontSizeMenuDidSelectItem:) keyEquivalent:@""];
            [item setRepresentedObject:fontSize];
            [menu addItem:item];
        }
        
        [NSMenu popUpContextMenu:menu withEvent:event forView:sender];
    }
}

- (void)showEditHyperLinkToolbar:(NSView *)sender {
    
    if (_toolbarPopover == nil) {
        EditHyperLinkToolbar *toolbar = [[EditHyperLinkToolbar alloc] initWithNibName:NSStringFromClass([EditHyperLinkToolbar class]) bundle:nil];
        toolbar.delegate = self;
        toolbar.hyperlink = self.hyperlink;
        _toolbarPopover = [[NSPopover alloc] init];
        [_toolbarPopover setBehavior:NSPopoverBehaviorApplicationDefined];
        [_toolbarPopover setAnimates:YES];
        [_toolbarPopover setContentViewController:toolbar];
        [_toolbarPopover setDelegate:self];
        [_toolbarPopover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSRectEdgeMinY];
    } else {
        [_toolbarPopover close];
    }
}

// MARK: - Actions

- (IBAction)fontMenuDidSelectItem:(id)sender {
    if ([sender isKindOfClass:[NSMenuItem class]] && [[(NSMenuItem *)sender representedObject] isKindOfClass:[NSFont class]]) {
        NSFont *font = (NSFont *)[((NSMenuItem *)sender) representedObject];
        
        [self.currentTextEditor userChangedToFontName:font.fontName];
        [self setFontNameButtonFont:font];
    }
}

- (IBAction)fontSizeMenuDidSelectItem:(id)sender {
    if ([sender isKindOfClass:[NSMenuItem class]] && [[(NSMenuItem *)sender representedObject] isKindOfClass:[NSNumber class]]) {
        NSNumber *fontSize = (NSNumber *)[((NSMenuItem *)sender) representedObject];
        
        [self.currentTextEditor userChangedToFontSize:fontSize];
    }
}

- (RichTextEditor *)currentTextEditor {
    if ([[self.view window] firstResponder] == self.textView) {
        return self.textView;
    }
    
    return self.textField;
}

- (IBAction)toggleBold:(id)sender {
    [self.currentTextEditor userSelectedBold];
}

- (IBAction)toggleItalic:(id)sender {
    [self.currentTextEditor userSelectedItalic];
}

- (IBAction)toggleUnderline:(id)sender {
    [self.currentTextEditor userSelectedUnderline];
}

- (IBAction)toggleStrikethrough:(id)sender {
    [self.currentTextEditor userSelectedStrikethrough];
}

- (IBAction)toggleBulletedList:(id)sender {
    [self.currentTextEditor userSelectedBullet];
}

- (IBAction)toggleOrderedList:(id)sender {
}

- (IBAction)decreaseIndent:(id)sender {
    [self.currentTextEditor userSelectedDecreaseIndent];
}

- (IBAction)increaseIndent:(id)sender {
    [self.currentTextEditor userSelectedIncreaseIndent];
}

- (IBAction)toggleFontName:(id)sender {
    if ([sender isKindOfClass:[NSView class]]) {
        [self showFontMenuAtSender:(NSView *)sender];
    }
}

- (IBAction)decreaseFontSize:(id)sender {
    [self.currentTextEditor decreaseFontSize];
}

- (IBAction)increaseFontSize:(id)sender {
    [self.currentTextEditor increaseFontSize];
}

- (IBAction)toggleFontSize:(id)sender {
    if ([sender isKindOfClass:[NSView class]]) {
        [self showFontSizeMenuAtSender:(NSView *)sender];
    }
}

- (IBAction)fontColorChanged:(id)sender {
    [self.currentTextEditor userSelectedTextColor:self.colorPickerButton.color];
}

- (IBAction)toggleHyperLink:(id)sender {
    if ([sender isKindOfClass:[NSView class]]) {
        [self showEditHyperLinkToolbar:(NSView *)sender];
    }
}

- (IBAction)tabAlwaysIndentsChecked:(id)sender {
    self.currentTextEditor.tabKeyAlwaysIndentsOutdents = self.tabKeyAlwaysIndentsButton.state == NSControlStateValueOn;
}

// MARK: - EditToolbarDelegate

- (void)toolbarDidChangeFormatLink:(NSURL *_Nullable)link {
    [_toolbarPopover close];
    [self.currentTextEditor userApplyHyperlink:link];
}

// MARK: - RichTextEditorDelegate

- (void)richTextEditorBecomesFirstResponder:(RichTextEditor *)editor {
    [self configToolbarForTextEditor];
}

- (void)richTextEditorResignsFirstResponder:(RichTextEditor *)editor {
}

- (void)richTextEditor:(RichTextEditor *)editor changeAboutToOccurOfType:(RichTextEditorPreviewChange)type {
    // NSLog(@"User just edited the RTE by performing this operation: %@", [RichTextEditor convertPreviewChangeTypeToString:type withNonSpecialChangeText:YES]);
}

- (void)richTextEditor:(RichTextEditor *)editor changedSelectionTo:(NSRange)range withFormat:(RTETextFormat *)textFormat {
    [_toolbarPopover close];
    
    if (textFormat.isBold) {
        self.boldButton.image = [[NSImage imageNamed:@"bold"] imageTintedWithColor:NSColor.blueColor];
    } else {
        self.boldButton.image = [[NSImage imageNamed:@"bold"] imageTintedWithColor:NSColor.blackColor];
    }
    
    if (textFormat.isItalic) {
        self.italicButton.image = [[NSImage imageNamed:@"italic"] imageTintedWithColor:NSColor.blueColor];
    } else {
        self.italicButton.image = [[NSImage imageNamed:@"italic"] imageTintedWithColor:NSColor.blackColor];
    }
    
    if (textFormat.isUnderline) {
        self.underlineButton.image = [[NSImage imageNamed:@"underline"] imageTintedWithColor:NSColor.blueColor];
    } else {
        self.underlineButton.image = [[NSImage imageNamed:@"underline"] imageTintedWithColor:NSColor.blackColor];
    }
    
    if (textFormat.isStrikethrough) {
        self.strikethroughButton.image = [[NSImage imageNamed:@"strike-through"] imageTintedWithColor:NSColor.blueColor];
    } else {
        self.strikethroughButton.image = [[NSImage imageNamed:@"strike-through"] imageTintedWithColor:NSColor.blackColor];
    }
    
    if (textFormat.isBulletedList) {
        self.bulletedListButton.image = [[NSImage imageNamed:@"bulleted-list"] imageTintedWithColor:NSColor.blueColor];
    } else {
        self.bulletedListButton.image = [[NSImage imageNamed:@"bulleted-list"] imageTintedWithColor:NSColor.blackColor];
    }
    
    if (textFormat.isOrderedList) {
        self.orderedListButton.image = [[NSImage imageNamed:@"ordered-list"] imageTintedWithColor:NSColor.blueColor];
    } else {
        self.orderedListButton.image = [[NSImage imageNamed:@"ordered-list"] imageTintedWithColor:NSColor.blackColor];
    }
    
    if (textFormat.textColor != nil) {
        self.colorPickerButton.color = textFormat.textColor;
    }
    
    if (textFormat.font != nil) {
        [self setFontNameButtonFont:textFormat.font];
    }
    
    [self.hyperlinkButton setEnabled:textFormat.hyperlinkEnabled];
    self.hyperlink = textFormat.hyperlink;
}

// MARK: - NSPopoverDelegate

- (void)popoverWillShow:(NSNotification *)notification {
}

- (void)popoverDidShow:(NSNotification *)notification {
}

- (void)popoverWillClose:(NSNotification *)notification {
}

- (void)popoverDidClose:(NSNotification *)notification {
    _toolbarPopover = nil;
}

@end
