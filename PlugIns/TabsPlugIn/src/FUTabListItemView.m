//  Copyright 2009 Todd Ditchendorf
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "FUTabListItemView.h"
#import "FUTabModel.h"
#import "FUUtils.h"
#import "FUTabsViewController.h"

#define NORMAL_RADIUS 4
#define SMALL_RADIUS 3
#define BGCOLOR_INSET 2
#define THUMBNAIL_DIFF 6

static NSDictionary *sSelectedTitleAttrs = nil;
static NSDictionary *sTitleAttrs = nil;

static NSGradient *sSelectedOuterRectFillGradient = nil;

static NSColor *sSelectedOuterRectStrokeColor = nil;

static NSGradient *sInnerRectFillGradient = nil;

static NSColor *sSelectedInnerRectStrokeColor = nil;
static NSColor *sInnerRectStrokeColor = nil;

@interface NSImage (FUAdditions)
- (NSImage *)scaledImageOfSize:(NSSize)size;
- (NSImage *)scaledImageOfSize:(NSSize)size alpha:(CGFloat)alpha;
@end

@interface FUTabListItemView ()
- (NSImage *)imageNamed:(NSString *)name scaledToSize:(NSSize)size;
- (void)startObserveringModel:(FUTabModel *)m;
- (void)stopObserveringModel:(FUTabModel *)m;
@end

@implementation FUTabListItemView

+ (void)initialize {
    if ([FUTabListItemView class] == self) {
        
        NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [paraStyle setAlignment:NSLeftTextAlignment];
        [paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        
        NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
        [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:.4]];
        [shadow setShadowOffset:NSMakeSize(0, -1)];
        [shadow setShadowBlurRadius:0];

        sSelectedTitleAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:
                               [NSFont boldSystemFontOfSize:10], NSFontAttributeName,
                               [NSColor whiteColor], NSForegroundColorAttributeName,
                               paraStyle, NSParagraphStyleAttributeName,
                               shadow, NSShadowAttributeName,
                               nil];

        sTitleAttrs = [[NSDictionary alloc] initWithObjectsAndKeys:
                               [NSFont boldSystemFontOfSize:10], NSFontAttributeName,
                               [NSColor colorWithDeviceWhite:.3 alpha:1], NSForegroundColorAttributeName,
                               paraStyle, NSParagraphStyleAttributeName,
                               nil];

        // outer round rect fill
        NSColor *fillTopColor = [NSColor colorWithDeviceRed:134.0/255.0 green:147.0/255.0 blue:169.0/255.0 alpha:1.0];
        NSColor *fillBottomColor = [NSColor colorWithDeviceRed:108.0/255.0 green:120.0/255.0 blue:141.0/255.0 alpha:1.0];
        sSelectedOuterRectFillGradient = [[NSGradient alloc] initWithStartingColor:fillTopColor endingColor:fillBottomColor];
        
        // outer round rect stroke
        sSelectedOuterRectStrokeColor = [[NSColor colorWithDeviceRed:91.0/255.0 green:100.0/255.0 blue:115.0/255.0 alpha:1.0] retain];

        // inner round rect fill
        sInnerRectFillGradient = [[NSGradient alloc] initWithStartingColor:[NSColor whiteColor] endingColor:[NSColor whiteColor]];
        
        sSelectedInnerRectStrokeColor = [[sSelectedOuterRectStrokeColor colorWithAlphaComponent:.8] retain];
        sInnerRectStrokeColor = [[NSColor colorWithDeviceWhite:.7 alpha:1] retain];
    }
}


+ (NSString *)identifier {
    return NSStringFromClass(self);
}


- (id)init {
    return [self initWithFrame:NSZeroRect reuseIdentifier:[[self class] identifier]];
}


- (id)initWithFrame:(NSRect)frame reuseIdentifier:(NSString *)s {
    if (self = [super initWithFrame:frame reuseIdentifier:s]) {
        self.closeButton = [[[NSButton alloc] initWithFrame:NSMakeRect(7, 5, 10, 10)] autorelease];
        [closeButton setButtonType:NSMomentaryChangeButton];
        [closeButton setBordered:NO];
        [closeButton setAction:@selector(closeTabButtonClick:)];

        NSSize imgSize = NSMakeSize(10, 10);
        [closeButton setImage:[self imageNamed:@"close_button" scaledToSize:imgSize]];
        [closeButton setAlternateImage:[self imageNamed:@"close_button_pressed" scaledToSize:imgSize]];
        [self addSubview:closeButton];
        
        self.progressIndicator = [[[NSProgressIndicator alloc] initWithFrame:NSZeroRect] autorelease];
        [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
        [progressIndicator setControlSize:NSSmallControlSize];
        [progressIndicator setDisplayedWhenStopped:NO];
        [progressIndicator setIndeterminate:YES];
        [progressIndicator sizeToFit];
        [self addSubview:progressIndicator];
    }
    return self;
}


- (void)dealloc {
    self.model = nil;
    self.closeButton = nil;
    self.progressIndicator = nil;
    self.viewController = nil;
    [super dealloc];
}


- (void)drawRect:(NSRect)dirtyRect {
    [closeButton setTag:model.index];
    [closeButton setTarget:viewController];

    NSRect bounds = [self bounds];
    
    // outer round rect
    if (bounds.size.width < 24.0) return; // dont draw anymore when you're really small. looks bad.

    NSRect roundRect = NSInsetRect(bounds, 2.5, 1.5);
    
    if (model.isSelected) {
        CGFloat radius = (bounds.size.width < 32) ? SMALL_RADIUS : NORMAL_RADIUS;
        FUDrawRoundRect(roundRect, radius, sSelectedOuterRectFillGradient, sSelectedOuterRectStrokeColor, 1);
    }

    // title
    if (bounds.size.width < 40.0) return; // dont draw anymore when you're really small. looks bad.

    NSRect titleRect = NSInsetRect(roundRect, 11, 2);
    titleRect.origin.x += 8; // make room for close button
    titleRect.size.height = 13;
    NSUInteger opts = NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin;
    NSDictionary *attrs = model.isSelected ? sSelectedTitleAttrs : sTitleAttrs;
    [model.title drawWithRect:titleRect options:opts attributes:attrs];
    
    // inner round rect
    if (bounds.size.width < 55.0) return; // dont draw anymore when you're really small. looks bad.

    roundRect = NSInsetRect(roundRect, 4, 4);
    roundRect = NSOffsetRect(roundRect, 0, 12);
    roundRect.size.height -= 10;
    
    NSImage *img = model.image;
    [img setFlipped:[self isFlipped]];

    NSGradient *grad = nil;
    if (img) {
        NSSize size = [img size];
        NSBitmapImageRep *bitmap = [[img representations] objectAtIndex:0];

        NSColor *fillTopColor = [bitmap colorAtX:size.width - BGCOLOR_INSET y:BGCOLOR_INSET];
        fillTopColor = fillTopColor ? fillTopColor : [NSColor whiteColor];

        NSColor *fillBottomColor = [bitmap colorAtX:BGCOLOR_INSET y:size.height - BGCOLOR_INSET];
        fillBottomColor = fillBottomColor ? fillBottomColor : [NSColor whiteColor];
        grad = [[[NSGradient alloc] initWithStartingColor:fillTopColor endingColor:fillBottomColor] autorelease];
    } else {
        grad = sInnerRectFillGradient;
    }

    NSColor *strokeColor = model.isSelected ? sSelectedInnerRectStrokeColor : sInnerRectStrokeColor;
    FUDrawRoundRect(roundRect, NORMAL_RADIUS, grad, strokeColor, 1);
    
    // draw image
    if (bounds.size.width < 64.0) return; // dont draw anymore when you're really small. looks bad.

    NSSize imgSize = roundRect.size;
    imgSize.width = floor(imgSize.width - THUMBNAIL_DIFF);
    imgSize.height = floor(imgSize.height - THUMBNAIL_DIFF);

    //    img = [img scaledImageOfSize:imgSize progress:model.estimatedProgress];
    img = [img scaledImageOfSize:imgSize alpha:model.isLoading ? .4 : 1];
    
    if (!img) return;
    imgSize = [img size];
    NSRect srcRect = NSMakeRect(0, 0, imgSize.width, imgSize.height);
    NSRect destRect = NSOffsetRect(srcRect, floor(roundRect.origin.x + THUMBNAIL_DIFF/2), floor(roundRect.origin.y + THUMBNAIL_DIFF/2));
    [img drawInRect:destRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1];
    
    if (model.isLoading) {
        [progressIndicator setFrameOrigin:NSMakePoint(NSMaxX(bounds) - 26, 20)];
        [progressIndicator startAnimation:self];
    } else {
        [progressIndicator stopAnimation:self];
    }
    [progressIndicator setNeedsDisplay:YES];
    [closeButton setNeedsDisplay:YES];
}


- (void)setModel:(FUTabModel *)m {
    if (m != model) {
        [self stopObserveringModel:model];
        
        [model autorelease];
        model = [m retain];
        
        [self startObserveringModel:model];
    }
}


- (NSImage *)imageNamed:(NSString *)name scaledToSize:(NSSize)size {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:name];
    return [[[[NSImage alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]] autorelease] scaledImageOfSize:size];
}


- (void)startObserveringModel:(FUTabModel *)m {
    if (m) {
        [m addObserver:self forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:NULL];
        [m addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
    }
}


- (void)stopObserveringModel:(FUTabModel *)m {
    if (m) {
        [m removeObserver:self forKeyPath:@"image"];
        [m removeObserver:self forKeyPath:@"title"];
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == model) {
        [self setNeedsDisplay:YES];
    }
}

@synthesize model;
@synthesize closeButton;
@synthesize progressIndicator;
@synthesize viewController;
@end