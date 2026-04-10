#import <Cocoa/Cocoa.h>

static NSColor *RGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [NSColor colorWithCalibratedRed:red / 255.0
                                     green:green / 255.0
                                      blue:blue / 255.0
                                     alpha:alpha];
}

static NSBezierPath *RoundedRect(CGRect rect, CGFloat radius) {
    return [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
}

static NSBezierPath *ShieldPath(CGRect rect) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    CGFloat midX = CGRectGetMidX(rect);

    [path moveToPoint:NSMakePoint(midX, maxY)];
    [path lineToPoint:NSMakePoint(maxX, maxY - rect.size.height * 0.12)];
    [path curveToPoint:NSMakePoint(maxX - rect.size.width * 0.05, minY + rect.size.height * 0.22)
         controlPoint1:NSMakePoint(maxX, maxY - rect.size.height * 0.32)
         controlPoint2:NSMakePoint(maxX, minY + rect.size.height * 0.48)];
    [path lineToPoint:NSMakePoint(midX, minY)];
    [path lineToPoint:NSMakePoint(minX + rect.size.width * 0.05, minY + rect.size.height * 0.22)];
    [path curveToPoint:NSMakePoint(minX, maxY - rect.size.height * 0.12)
         controlPoint1:NSMakePoint(minX, minY + rect.size.height * 0.48)
         controlPoint2:NSMakePoint(minX, maxY - rect.size.height * 0.32)];
    [path closePath];
    return path;
}

static void DrawCheckmark(CGRect rect) {
    NSBezierPath *check = [NSBezierPath bezierPath];
    check.lineWidth = rect.size.width * 0.11;
    check.lineCapStyle = NSLineCapStyleRound;
    check.lineJoinStyle = NSLineJoinStyleRound;
    [check moveToPoint:NSMakePoint(CGRectGetMinX(rect) + rect.size.width * 0.14, CGRectGetMidY(rect) - rect.size.height * 0.02)];
    [check lineToPoint:NSMakePoint(CGRectGetMinX(rect) + rect.size.width * 0.42, CGRectGetMinY(rect) + rect.size.height * 0.18)];
    [check lineToPoint:NSMakePoint(CGRectGetMaxX(rect) - rect.size.width * 0.10, CGRectGetMaxY(rect) - rect.size.height * 0.14)];

    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowBlurRadius = rect.size.width * 0.03;
    shadow.shadowOffset = NSMakeSize(0, -rect.size.height * 0.02);
    shadow.shadowColor = [RGB(0, 70, 180, 0.35) colorWithAlphaComponent:0.35];
    [NSGraphicsContext saveGraphicsState];
    [shadow set];
    [[NSColor whiteColor] setStroke];
    [check stroke];
    [NSGraphicsContext restoreGraphicsState];
}

static void DrawTrashCan(CGRect rect) {
    CGFloat topHeight = rect.size.height * 0.18;
    CGRect lidRect = CGRectMake(CGRectGetMinX(rect) + rect.size.width * 0.08,
                                CGRectGetMaxY(rect) - topHeight,
                                rect.size.width * 0.84,
                                topHeight * 0.60);
    NSBezierPath *lid = RoundedRect(lidRect, lidRect.size.height * 0.48);
    NSGradient *silver = [[NSGradient alloc] initWithColorsAndLocations:
                          RGB(245, 249, 255, 1.0), 0.0,
                          RGB(214, 223, 235, 1.0), 0.45,
                          RGB(130, 146, 170, 1.0), 1.0,
                          nil];
    [silver drawInBezierPath:lid angle:90];
    [[RGB(32, 67, 120, 0.9) colorWithAlphaComponent:0.9] setStroke];
    lid.lineWidth = rect.size.width * 0.018;
    [lid stroke];

    CGRect bodyRect = CGRectMake(CGRectGetMinX(rect) + rect.size.width * 0.16,
                                 CGRectGetMinY(rect),
                                 rect.size.width * 0.68,
                                 rect.size.height * 0.74);
    NSBezierPath *body = [NSBezierPath bezierPath];
    [body moveToPoint:NSMakePoint(CGRectGetMinX(bodyRect) + bodyRect.size.width * 0.10, CGRectGetMaxY(bodyRect))];
    [body lineToPoint:NSMakePoint(CGRectGetMaxX(bodyRect) - bodyRect.size.width * 0.10, CGRectGetMaxY(bodyRect))];
    [body curveToPoint:NSMakePoint(CGRectGetMaxX(bodyRect) - bodyRect.size.width * 0.18, CGRectGetMinY(bodyRect))
        controlPoint1:NSMakePoint(CGRectGetMaxX(bodyRect), CGRectGetMaxY(bodyRect) - bodyRect.size.height * 0.18)
        controlPoint2:NSMakePoint(CGRectGetMaxX(bodyRect), CGRectGetMinY(bodyRect) + bodyRect.size.height * 0.08)];
    [body lineToPoint:NSMakePoint(CGRectGetMinX(bodyRect) + bodyRect.size.width * 0.18, CGRectGetMinY(bodyRect))];
    [body curveToPoint:NSMakePoint(CGRectGetMinX(bodyRect) + bodyRect.size.width * 0.10, CGRectGetMaxY(bodyRect))
        controlPoint1:NSMakePoint(CGRectGetMinX(bodyRect), CGRectGetMinY(bodyRect) + bodyRect.size.height * 0.08)
        controlPoint2:NSMakePoint(CGRectGetMinX(bodyRect), CGRectGetMaxY(bodyRect) - bodyRect.size.height * 0.18)];
    [body closePath];

    [silver drawInBezierPath:body angle:90];
    [[RGB(25, 55, 106, 1.0) colorWithAlphaComponent:0.95] setStroke];
    body.lineWidth = rect.size.width * 0.018;
    [body stroke];

    NSInteger columns = 5;
    NSInteger rows = 4;
    CGFloat slotWidth = bodyRect.size.width * 0.10;
    CGFloat slotHeight = bodyRect.size.height * 0.15;
    NSArray<NSColor *> *slotColors = @[
        RGB(97, 199, 255, 0.95),
        RGB(136, 236, 139, 0.95),
        RGB(255, 210, 73, 0.95),
        RGB(255, 123, 128, 0.95),
        RGB(168, 142, 255, 0.95)
    ];

    for (NSInteger row = 0; row < rows; row += 1) {
        for (NSInteger column = 0; column < columns; column += 1) {
            CGFloat x = CGRectGetMinX(bodyRect) + bodyRect.size.width * 0.16 + column * bodyRect.size.width * 0.11;
            CGFloat y = CGRectGetMinY(bodyRect) + bodyRect.size.height * 0.08 + row * bodyRect.size.height * 0.16;
            NSBezierPath *slot = RoundedRect(CGRectMake(x, y, slotWidth, slotHeight), slotWidth * 0.24);
            NSColor *color = slotColors[(NSUInteger)((row + column) % slotColors.count)];
            [[color blendedColorWithFraction:0.35 ofColor:[NSColor whiteColor]] setFill];
            [slot fill];
            [[RGB(17, 52, 108, 0.85) colorWithAlphaComponent:0.85] setStroke];
            slot.lineWidth = rect.size.width * 0.007;
            [slot stroke];
        }
    }
}

static void DrawFolder(CGRect rect, NSColor *fillColor) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat radius = rect.size.width * 0.08;
    [path moveToPoint:NSMakePoint(CGRectGetMinX(rect), CGRectGetMinY(rect) + radius)];
    [path lineToPoint:NSMakePoint(CGRectGetMinX(rect), CGRectGetMaxY(rect) - radius)];
    [path curveToPoint:NSMakePoint(CGRectGetMinX(rect) + radius, CGRectGetMaxY(rect))
         controlPoint1:NSMakePoint(CGRectGetMinX(rect), CGRectGetMaxY(rect) - radius * 0.3)
         controlPoint2:NSMakePoint(CGRectGetMinX(rect) + radius * 0.3, CGRectGetMaxY(rect))];
    [path lineToPoint:NSMakePoint(CGRectGetMinX(rect) + rect.size.width * 0.34, CGRectGetMaxY(rect))];
    [path lineToPoint:NSMakePoint(CGRectGetMinX(rect) + rect.size.width * 0.44, CGRectGetMaxY(rect) + rect.size.height * 0.13)];
    [path lineToPoint:NSMakePoint(CGRectGetMaxX(rect) - radius, CGRectGetMaxY(rect) + rect.size.height * 0.13)];
    [path curveToPoint:NSMakePoint(CGRectGetMaxX(rect), CGRectGetMaxY(rect) - radius)
         controlPoint1:NSMakePoint(CGRectGetMaxX(rect) - radius * 0.3, CGRectGetMaxY(rect) + rect.size.height * 0.13)
         controlPoint2:NSMakePoint(CGRectGetMaxX(rect), CGRectGetMaxY(rect) - radius * 0.3)];
    [path lineToPoint:NSMakePoint(CGRectGetMaxX(rect), CGRectGetMinY(rect) + radius)];
    [path curveToPoint:NSMakePoint(CGRectGetMaxX(rect) - radius, CGRectGetMinY(rect))
         controlPoint1:NSMakePoint(CGRectGetMaxX(rect), CGRectGetMinY(rect) + radius * 0.3)
         controlPoint2:NSMakePoint(CGRectGetMaxX(rect) - radius * 0.3, CGRectGetMinY(rect))];
    [path lineToPoint:NSMakePoint(CGRectGetMinX(rect) + radius, CGRectGetMinY(rect))];
    [path curveToPoint:NSMakePoint(CGRectGetMinX(rect), CGRectGetMinY(rect) + radius)
         controlPoint1:NSMakePoint(CGRectGetMinX(rect) + radius * 0.3, CGRectGetMinY(rect))
         controlPoint2:NSMakePoint(CGRectGetMinX(rect), CGRectGetMinY(rect) + radius * 0.3)];
    [path closePath];
    [fillColor setFill];
    [path fill];
    [[RGB(30, 69, 125, 1.0) colorWithAlphaComponent:0.95] setStroke];
    path.lineWidth = rect.size.width * 0.08;
    [path stroke];
}

static void DrawDocument(CGRect rect, NSColor *fillColor) {
    NSBezierPath *paper = RoundedRect(rect, rect.size.width * 0.12);
    [fillColor setFill];
    [paper fill];
    [[RGB(34, 70, 120, 0.95) colorWithAlphaComponent:0.95] setStroke];
    paper.lineWidth = rect.size.width * 0.08;
    [paper stroke];

    for (NSInteger i = 0; i < 3; i += 1) {
        CGFloat y = CGRectGetMaxY(rect) - rect.size.height * (0.28 + i * 0.20);
        NSBezierPath *line = [NSBezierPath bezierPath];
        line.lineWidth = rect.size.width * 0.08;
        line.lineCapStyle = NSLineCapStyleRound;
        [line moveToPoint:NSMakePoint(CGRectGetMinX(rect) + rect.size.width * 0.20, y)];
        [line lineToPoint:NSMakePoint(CGRectGetMaxX(rect) - rect.size.width * 0.20, y)];
        [[RGB(150, 90, 190, 0.65) colorWithAlphaComponent:(i == 0 ? 0.75 : 0.45)] setStroke];
        [line stroke];
    }
}

static void DrawArrowRing(CGRect rect) {
    NSBezierPath *leftArc = [NSBezierPath bezierPath];
    leftArc.lineWidth = rect.size.width * 0.028;
    leftArc.lineCapStyle = NSLineCapStyleRound;
    [leftArc appendBezierPathWithArcWithCenter:NSMakePoint(CGRectGetMidX(rect), CGRectGetMidY(rect))
                                        radius:rect.size.width * 0.40
                                    startAngle:155
                                      endAngle:320
                                     clockwise:NO];
    [[RGB(132, 237, 255, 0.75) colorWithAlphaComponent:0.75] setStroke];
    [leftArc stroke];
}

static void DrawSparkle(CGPoint center, CGFloat size) {
    NSBezierPath *sparkle = [NSBezierPath bezierPath];
    [sparkle moveToPoint:NSMakePoint(center.x, center.y + size)];
    [sparkle lineToPoint:NSMakePoint(center.x + size * 0.24, center.y + size * 0.24)];
    [sparkle lineToPoint:NSMakePoint(center.x + size, center.y)];
    [sparkle lineToPoint:NSMakePoint(center.x + size * 0.24, center.y - size * 0.24)];
    [sparkle lineToPoint:NSMakePoint(center.x, center.y - size)];
    [sparkle lineToPoint:NSMakePoint(center.x - size * 0.24, center.y - size * 0.24)];
    [sparkle lineToPoint:NSMakePoint(center.x - size, center.y)];
    [sparkle lineToPoint:NSMakePoint(center.x - size * 0.24, center.y + size * 0.24)];
    [sparkle closePath];
    [[RGB(255, 248, 186, 0.95) colorWithAlphaComponent:0.95] setFill];
    [sparkle fill];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: build_icon <output-png-path>\n");
            return 1;
        }

        NSString *outputPath = [NSString stringWithUTF8String:argv[1]];
        const CGFloat canvasSize = 1024.0;
        CGRect canvas = CGRectMake(0, 0, canvasSize, canvasSize);

        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                                 initWithBitmapDataPlanes:NULL
                                 pixelsWide:(NSInteger)canvasSize
                                 pixelsHigh:(NSInteger)canvasSize
                                 bitsPerSample:8
                                 samplesPerPixel:4
                                 hasAlpha:YES
                                 isPlanar:NO
                                 colorSpaceName:NSCalibratedRGBColorSpace
                                 bytesPerRow:0
                                 bitsPerPixel:0];

        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:context];

        [[NSColor clearColor] setFill];
        NSRectFill(canvas);

        NSShadow *outerShadow = [[NSShadow alloc] init];
        outerShadow.shadowBlurRadius = 36.0;
        outerShadow.shadowOffset = NSMakeSize(0, -16);
        outerShadow.shadowColor = [RGB(40, 57, 95, 0.20) colorWithAlphaComponent:0.2];
        [outerShadow set];

        CGRect tileRect = CGRectInset(canvas, 70, 70);
        NSBezierPath *tile = RoundedRect(tileRect, 110);
        NSGradient *tileGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                    RGB(118, 226, 255, 1.0), 0.0,
                                    RGB(36, 153, 255, 1.0), 0.54,
                                    RGB(17, 70, 205, 1.0), 1.0,
                                    nil];
        [tileGradient drawInBezierPath:tile angle:90];

        [[RGB(18, 66, 160, 0.95) colorWithAlphaComponent:0.95] setStroke];
        tile.lineWidth = 8.0;
        [tile stroke];

        NSBezierPath *tileGloss = RoundedRect(CGRectMake(CGRectGetMinX(tileRect) + 26,
                                                         CGRectGetMidY(tileRect) + 80,
                                                         tileRect.size.width - 52,
                                                         tileRect.size.height * 0.38),
                                              96);
        [[RGB(255, 255, 255, 0.10) colorWithAlphaComponent:0.10] setFill];
        [tileGloss fill];

        CGRect shieldRect = CGRectMake(220, 150, 584, 730);
        NSBezierPath *shield = ShieldPath(shieldRect);
        NSGradient *shieldFill = [[NSGradient alloc] initWithColorsAndLocations:
                                  RGB(96, 220, 255, 0.95), 0.0,
                                  RGB(32, 118, 235, 0.98), 0.45,
                                  RGB(14, 44, 126, 1.0), 1.0,
                                  nil];
        [shieldFill drawInBezierPath:shield angle:90];

        NSBezierPath *shieldBorder = ShieldPath(CGRectInset(shieldRect, 0, 0));
        shieldBorder.lineWidth = 26.0;
        NSGradient *metal = [[NSGradient alloc] initWithColorsAndLocations:
                             RGB(255, 255, 255, 1.0), 0.0,
                             RGB(218, 226, 236, 1.0), 0.42,
                             RGB(125, 139, 165, 1.0), 1.0,
                             nil];
        [NSGraphicsContext saveGraphicsState];
        [shieldBorder setClip];
        [metal drawInRect:NSInsetRect(shieldRect, -20, -20) angle:90];
        [NSGraphicsContext restoreGraphicsState];
        [[RGB(29, 75, 140, 0.95) colorWithAlphaComponent:0.95] setStroke];
        [shieldBorder stroke];

        CGRect innerShieldRect = CGRectInset(shieldRect, 40, 52);
        NSBezierPath *innerShield = ShieldPath(innerShieldRect);
        NSGradient *innerGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                     RGB(112, 227, 255, 0.96), 0.0,
                                     RGB(36, 140, 245, 0.96), 0.48,
                                     RGB(19, 63, 160, 1.0), 1.0,
                                     nil];
        [innerGradient drawInBezierPath:innerShield angle:90];
        [[RGB(17, 55, 112, 0.85) colorWithAlphaComponent:0.85] setStroke];
        innerShield.lineWidth = 10.0;
        [innerShield stroke];

        DrawArrowRing(CGRectInset(innerShieldRect, 30, 40));
        DrawCheckmark(CGRectMake(382, 226, 286, 220));

        DrawFolder(CGRectMake(332, 492, 92, 68), RGB(255, 169, 53, 1.0));
        DrawDocument(CGRectMake(450, 500, 72, 88), RGB(251, 252, 255, 1.0));
        DrawDocument(CGRectMake(554, 514, 72, 92), RGB(252, 236, 255, 1.0));

        NSBezierPath *gear = [NSBezierPath bezierPathWithOvalInRect:CGRectMake(610, 490, 56, 56)];
        [[RGB(180, 196, 216, 1.0) colorWithAlphaComponent:1.0] setFill];
        [gear fill];
        [[RGB(39, 74, 130, 0.9) colorWithAlphaComponent:0.9] setStroke];
        gear.lineWidth = 8.0;
        [gear stroke];

        DrawTrashCan(CGRectMake(300, 250, 420, 320));
        DrawSparkle(CGPointMake(360, 640), 14);
        DrawSparkle(CGPointMake(646, 622), 12);
        DrawSparkle(CGPointMake(705, 560), 10);

        [NSGraphicsContext restoreGraphicsState];

        NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (![pngData writeToFile:outputPath atomically:YES]) {
            fprintf(stderr, "failed to write png output\n");
            return 1;
        }
    }
    return 0;
}
