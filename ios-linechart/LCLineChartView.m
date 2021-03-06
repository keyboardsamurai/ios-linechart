//
//  LCLineChartView.m
//
//
//  Created by Marcel Ruegenberg on 02.08.13.
//
//

#import <tgmath.h>
#import <ios-linechart/LCLineChartView.h>
#import "LCLineChartView.h"
#import "LCLegendView.h"
#import "LCInfoView.h"

@interface LCLineChartDataItem ()

@property (readwrite) double x; // should be within the x range
@property (readwrite) double y; // should be within the y range
@property (readwrite) NSString *xLabel; // label to be shown on the x axis
@property (readwrite) NSString *dataLabel; // label to be shown directly at the data item

- (id)initWithhX:(double)x y:(double)y xLabel:(NSString *)xLabel dataLabel:(NSString *)dataLabel;

@end

@implementation LCLineChartDataItem

- (id)initWithhX:(double)x y:(double)y xLabel:(NSString *)xLabel dataLabel:(NSString *)dataLabel {
    if((self = [super init])) {
        self.x = x;
        self.y = y;
        self.xLabel = xLabel;
        self.dataLabel = dataLabel;
    }
    return self;
}

+ (LCLineChartDataItem *)dataItemWithX:(double)x y:(double)y xLabel:(NSString *)xLabel dataLabel:(NSString *)dataLabel {
    return [[LCLineChartDataItem alloc] initWithhX:x y:y xLabel:xLabel dataLabel:dataLabel];
}

@end



@implementation LCLineChartData

- (id)init {
    self = [super init];
    if(self) {
        self.drawsDataPoints = YES;
    }
    return self;
}

@end



@interface LCLineChartView ()



@property UIView *currentPosView;
@property UILabel *xAxisLabel;

- (BOOL)drawsAnyData;

@property LCLineChartData *selectedData;
@property NSUInteger selectedIdx;

@end


#define X_AXIS_SPACE 15
#define PADDING 10


@implementation LCLineChartView {
    double yAxisOrigin;
}
@synthesize data=_data;



- (void)setDefaultValues {
    self.currentPosView = [[UIView alloc] initWithFrame:CGRectMake(PADDING, PADDING, 1 / self.contentScaleFactor, 50)];
    self.currentPosView.backgroundColor = UIColor.clearColor;
    self.currentPosView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.currentPosView.alpha = 0.0;
    [self addSubview:self.currentPosView];

    self.legendView = [[LCLegendView alloc] init];
    self.legendView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.legendView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.legendView];

    self.axisLabelColor = [UIColor grayColor];

    self.xAxisLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 20)];
    self.xAxisLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.xAxisLabel.font = [UIFont boldSystemFontOfSize:10];
    self.xAxisLabel.textColor = self.axisLabelColor;
    self.xAxisLabel.textAlignment = NSTextAlignmentCenter;
    self.xAxisLabel.alpha = 0.0;
    self.xAxisLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:self.xAxisLabel];

    self.backgroundColor = [UIColor whiteColor];
    self.scaleFont = [UIFont systemFontOfSize:10.0];

    self.autoresizesSubviews = YES;
    self.contentMode = UIViewContentModeRedraw;

    self.drawsDataPoints = YES;
    self.drawsDataLines  = YES;

    self.selectedIdx = INT_MAX;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if((self = [super initWithCoder:aDecoder])) {
        [self setDefaultValues];
        self.infoViewList = [NSMutableArray new];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if((self = [super initWithFrame:frame])) {
        [self setDefaultValues];
        self.infoViewList = [NSMutableArray new];
    }
    return self;
}

- (void)setAxisLabelColor:(UIColor *)axisLabelColor {
    if(axisLabelColor != _axisLabelColor) {
        [self willChangeValueForKey:@"axisLabelColor"];
        _axisLabelColor = axisLabelColor;
        self.xAxisLabel.textColor = axisLabelColor;
        [self didChangeValueForKey:@"axisLabelColor"];
    }
}

- (void)showLegend:(BOOL)show animated:(BOOL)animated {
    if(! animated) {
        self.legendView.alpha = show ? 1.0 : 0.0;
        return;
    }

    [UIView animateWithDuration:0.3 animations:^{
        self.legendView.alpha = show ? 1.0 : 0.0;
    }];
}

- (void)layoutSubviews {
    [self.legendView sizeToFit];
    CGRect r = self.legendView.frame;
    r.origin.x = self.bounds.size.width - self.legendView.frame.size.width - 3 - PADDING;
    r.origin.y = 3 + PADDING;
    self.legendView.frame = r;

    r = self.currentPosView.frame;
    CGFloat h = self.bounds.size.height;
    r.size.height = h - 2 * PADDING - X_AXIS_SPACE;
    self.currentPosView.frame = r;

    [self.xAxisLabel sizeToFit];
    r = self.xAxisLabel.frame;
    r.origin.y = self.bounds.size.height - X_AXIS_SPACE - PADDING + 2;
    self.xAxisLabel.frame = r;

    [self bringSubviewToFront:self.legendView];
}

- (void)setData:(NSArray *)data {
    if(data != _data) {
        [self hideIndicator];
        NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[data count]];
        NSMutableDictionary *colors = [NSMutableDictionary dictionaryWithCapacity:[data count]];
        for(LCLineChartData *dat in data) {
            NSString *key = dat.title;
            if(key == nil) key = @"";
            [titles addObject:key];
            [colors setObject:dat.color forKey:key];
        }
        self.legendView.titles = titles;
        self.legendView.colors = colors;
        self.selectedData = nil;
        self.selectedIdx = INT_MAX;

        _data = data;

        [self drawAllIndicators];
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    CGContextRef c = UIGraphicsGetCurrentContext();

    CGFloat availableHeight = self.bounds.size.height - 2 * PADDING - X_AXIS_SPACE;

    CGFloat availableWidth = self.bounds.size.width - 2 * PADDING - self.yAxisLabelsWidth;
    CGFloat xStart = PADDING + self.yAxisLabelsWidth;
    CGFloat yStart = PADDING;

    static CGFloat dashedPattern[] = {4,2};

    // draw scale and horizontal lines
    CGFloat heightPerStep = self.ySteps == nil || [self.ySteps count] <= 1 ? availableHeight : (availableHeight / ([self.ySteps count] - 1));

    NSUInteger i = 0;
    CGContextSaveGState(c);
    CGContextSetLineWidth(c, 1.0);
    NSUInteger yCnt = [self.ySteps count];
    for(NSString *step in self.ySteps) {
        [self.axisLabelColor set];
        CGFloat h = [self.scaleFont lineHeight];
        CGFloat y = yStart + heightPerStep * (yCnt - 1 - i);
        // TODO: replace with new text APIs in iOS 7 only version
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [step drawInRect:CGRectMake(yStart, y - h / 2, self.yAxisLabelsWidth - 6, h) withFont:self.scaleFont lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentRight];
#pragma clagn diagnostic pop

        [[UIColor colorWithWhite:0.9 alpha:1.0] set];
        if(i == 0 && self.drawAxis){
            // draw only lower horizontal axis line
            yAxisOrigin = round(y) + 0.5;
            // NSLog(@"x: %f y: %f",xStart-2,yAxisOrigin);
            CGContextMoveToPoint(c, xStart, yAxisOrigin);
            CGContextAddLineToPoint(c, self.bounds.size.width - PADDING, round(y) + 0.5);
            CGContextStrokePath(c);
        }

        i++;
    }
    if(self.drawAxis){
        // NSLog(@"x: %f y: %f",xStart-2,yAxisOrigin);
        // draw vertical axis line
        CGContextMoveToPoint(c, xStart, 0);
        CGContextAddLineToPoint(c, xStart, yAxisOrigin);
        CGContextStrokePath(c);
    }

    NSUInteger xCnt = self.xStepsCount;
    if(xCnt > 1) {
        CGFloat widthPerStep = availableWidth / (xCnt - 1);

        [[UIColor grayColor] set];
        for(NSUInteger i = 0; i < xCnt; ++i) {
            CGFloat x = xStart + widthPerStep * (xCnt - 1 - i);

            [[UIColor colorWithWhite:0.9 alpha:1.0] set];
            CGContextMoveToPoint(c, round(x) + 0.5, PADDING);
            CGContextAddLineToPoint(c, round(x) + 0.5, yStart + availableHeight);
            CGContextStrokePath(c);
        }
    }

    CGContextRestoreGState(c);


    if (!self.drawsAnyData) {
        NSLog(@"You configured LineChartView to draw neither lines nor data points. No data will be visible. This is most likely not what you wanted. (But we aren't judging you, so here's your chart background.)");
    } // warn if no data will be drawn

    CGFloat yRangeLen = self.yMax - self.yMin;
    if(yRangeLen == 0) yRangeLen = 1;
    for(LCLineChartData *data in self.data) {
        if (self.drawsDataLines) {
            double xRangeLen = data.xMax - data.xMin;
            if(xRangeLen == 0) xRangeLen = 1;
            if(data.itemCount >= 2) {
                LCLineChartDataItem *datItem = data.getData(0);
                CGMutablePathRef path = CGPathCreateMutable();
                CGFloat prevX = xStart + round(((datItem.x - data.xMin) / xRangeLen) * availableWidth);
                CGFloat prevY = yStart + round((1.0 - (datItem.y - self.yMin) / yRangeLen) * availableHeight);
                CGPathMoveToPoint(path, NULL, prevX, prevY);
                for(NSUInteger i = 1; i < data.itemCount; ++i) {
                    LCLineChartDataItem *datItem = data.getData(i);
                    CGFloat x = xStart + round(((datItem.x - data.xMin) / xRangeLen) * availableWidth);
                    CGFloat y = yStart + round((1.0 - (datItem.y - self.yMin) / yRangeLen) * availableHeight);
                    CGFloat xDiff = x - prevX;
                    CGFloat yDiff = y - prevY;

                    if(xDiff != 0) {
                        CGFloat xSmoothing = self.smoothPlot ? MIN(30,xDiff) : 0;
                        CGFloat ySmoothing = 0.5;
                        CGFloat slope = yDiff / xDiff;
                        CGPoint controlPt1 = CGPointMake(prevX + xSmoothing, prevY + ySmoothing * slope * xSmoothing);
                        CGPoint controlPt2 = CGPointMake(x - xSmoothing, y - ySmoothing * slope * xSmoothing);
                        CGPathAddCurveToPoint(path, NULL, controlPt1.x, controlPt1.y, controlPt2.x, controlPt2.y, x, y);
                    }
                    else {
                        CGPathAddLineToPoint(path, NULL, x, y);
                    }
                    prevX = x;
                    prevY = y;
                }

                CGContextAddPath(c, path);
                CGContextSetStrokeColorWithColor(c, [self.backgroundColor CGColor]);
                CGContextSetLineWidth(c, 5);
                CGContextStrokePath(c);

                CGContextAddPath(c, path);
                CGContextSetStrokeColorWithColor(c, [data.color CGColor]);
                CGContextSetLineWidth(c, 1);
                CGContextStrokePath(c);

                CGPathRelease(path);
            }
        } // draw actual chart data
        if (self.drawsDataPoints) {
            if (data.drawsDataPoints) {
                double xRangeLen = data.xMax - data.xMin;
                if(xRangeLen == 0) xRangeLen = 1;
                for(NSUInteger i = 0; i < data.itemCount; ++i) {
                    LCLineChartDataItem *datItem = data.getData(i);
                    CGFloat xVal = xStart + round((xRangeLen == 0 ? 0.5 : ((datItem.x - data.xMin) / xRangeLen)) * availableWidth);
                    CGFloat yVal = yStart + round((1.0 - (datItem.y - self.yMin) / yRangeLen) * availableHeight);
                    [self.backgroundColor setFill];
                    //CGContextFillEllipseInRect(c, CGRectMake(xVal - pointRadius/2, yVal - pointRadius/2, pointRadius, pointRadius));
                    if(data.dataPointColor){
                        [data.dataPointColor setFill];
                    }else{
                        [data.color setFill];
                    }

                    int pointRadius = 4;
                    CGContextFillEllipseInRect(c, CGRectMake(xVal - pointRadius/2, yVal - pointRadius/2, pointRadius, pointRadius));

                } // for
            } // data - draw data points
        } // draw data points
    }
}

- (void)showIndicatorAtPoint:(CGPoint )cgPoint {
    if(!self.showIndicator){
        // don't draw info indicators
        return;
    }

    LCInfoView *infoView = [[LCInfoView alloc] init];
    
    [self addSubview:infoView];
    [self.infoViewList addObject:infoView];

    CGPoint pos = cgPoint;
    CGFloat xStart = PADDING + self.yAxisLabelsWidth;
    CGFloat yStart = PADDING;
    CGFloat yRangeLen = self.yMax - self.yMin;
    if(yRangeLen == 0) yRangeLen = 1;
    CGFloat xPos = pos.x - xStart;
    CGFloat yPos = pos.y - yStart;
    CGFloat availableWidth = self.bounds.size.width - 2 * PADDING - self.yAxisLabelsWidth;
    CGFloat availableHeight = self.bounds.size.height - 2 * PADDING - X_AXIS_SPACE;

    LCLineChartDataItem *closest = nil;
    LCLineChartData *closestData = nil;
    NSUInteger closestIdx = INT_MAX;
    double minDist = DBL_MAX;
    double minDistY = DBL_MAX;
    CGPoint closestPos = CGPointZero;

    for(LCLineChartData *data in self.data) {
        double xRangeLen = data.xMax - data.xMin;

        // note: if necessary, could use binary search here to speed things up
        for(NSUInteger i = 0; i < data.itemCount; ++i) {
            LCLineChartDataItem *datItem = data.getData(i);
            CGFloat xVal = round((xRangeLen == 0 ? 0.0 : ((datItem.x - data.xMin) / xRangeLen)) * availableWidth);
            CGFloat yVal = round((1.0 - (datItem.y - self.yMin) / yRangeLen) * availableHeight);

            double dist = fabsf(xVal - xPos);
            double distY = fabsf(yVal - yPos);
            if(dist < minDist || (dist == minDist && distY < minDistY)) {
                minDist = dist;
                minDistY = distY;
                closest = datItem;
                closestData = data;
                closestIdx = i;
                closestPos = CGPointMake(xStart + xVal - 3, yStart + yVal - 7);
            }
        }
    }

    if(closest == nil || (closestData == self.selectedData && closestIdx == self.selectedIdx))
        return;

    self.selectedData = closestData;
    self.selectedIdx = closestIdx;

    infoView.infoLabel.text = closest.dataLabel;
    infoView.tapPoint = closestPos;
    [infoView sizeToFit];
    [infoView setNeedsLayout];
    [infoView setNeedsDisplay];

    if(self.currentPosView.alpha == 0.0) {
        CGRect r = self.currentPosView.frame;
        r.origin.x = closestPos.x + 3 - 1;
        self.currentPosView.frame = r;
    }

    [UIView animateWithDuration:0.1 animations:^{
        infoView.alpha = 1.0;
        self.currentPosView.alpha = 1.0;
        self.xAxisLabel.alpha = 1.0;

        CGRect r = self.currentPosView.frame;
        r.origin.x = closestPos.x + 3 - 1;
        self.currentPosView.frame = r;

        self.xAxisLabel.text = closest.xLabel;
        if(self.xAxisLabel.text != nil) {
            [self.xAxisLabel sizeToFit];
            r = self.xAxisLabel.frame;
            r.origin.x = round(closestPos.x - r.size.width / 2);
            self.xAxisLabel.frame = r;
        }
    }];

    if(self.selectedItemCallback != nil) {
        self.selectedItemCallback(closestData, closestIdx, closestPos);
    }
}

- (void)hideIndicator {
    for (LCInfoView *infoView in self.infoViewList) {
        if(self.deselectedItemCallback)
            self.deselectedItemCallback();

        self.selectedData = nil;

        [UIView animateWithDuration:0.1 animations:^{
            infoView.alpha = 0.0;
            self.currentPosView.alpha = 0.0;
            self.xAxisLabel.alpha = 0.0;
        }];
    }
}


- (void)drawAllIndicators {
    NSUInteger maximumLabels = 13;
    for(LCLineChartData *data in self.data) {
        double xRangeLen = data.xMax - data.xMin;
        NSUInteger labelDistance = (NSUInteger) ceil((float)data.itemCount/(float)maximumLabels);
        int counter=0;
        // note: if necessary, could use binary search here to speed things up
        for (NSUInteger i = 0; i < data.itemCount; ++i) {
            LCLineChartDataItem *datItem = data.getData(i);

            CGFloat availableWidth = self.bounds.size.width - 2 * PADDING - self.yAxisLabelsWidth;
            CGFloat availableHeight = self.bounds.size.height - 2 * PADDING - X_AXIS_SPACE;
            CGFloat xVal = round((xRangeLen == 0 ? 0.0 : ((datItem.x - data.xMin) / xRangeLen)) * availableWidth);
            CGFloat yRangeLen = self.yMax - self.yMin;
            CGFloat yVal = round((1.0 - (datItem.y - self.yMin) / yRangeLen) * availableHeight);

            CGPoint cgPoint = CGPointMake(xVal, yVal);
            if(data.itemCount <= maximumLabels){
                // we have less than maximumLabels data items so everyone gets a label
                [self showIndicatorAtPoint:cgPoint];
            }else if(labelDistance > 0){
                NSUInteger mod =  counter % labelDistance;
                if(counter !=0  // keeps first label from overlapping
                        && mod == 0){
                    [self showIndicatorAtPoint:cgPoint];
                }
            }
            counter++;
        }
    }
}


#pragma mark Helper methods

- (BOOL)drawsAnyData {
    return self.drawsDataPoints || self.drawsDataLines;
}

// TODO: This should really be a cached value. Invalidated iff ySteps changes.
- (CGFloat)yAxisLabelsWidth {
    double maxV = 0;
    for(NSString *label in self.ySteps) {
        CGSize labelSize = [label sizeWithFont:self.scaleFont];
        if(labelSize.width > maxV) maxV = labelSize.width;
    }
    return maxV + PADDING;
}

@end
