//
//  ViewController.m
//  SimpleMap
//
//  Created by Pavel on 01.02.2018.
//  Copyright © 2018 Pavel Maiboroda. All rights reserved.
//

#import "ViewController.h"
#import "PMStudent.h"
#import <MapKit/MapKit.h>
#import "UIView+MKAnnotationView.h"
#import "PMDetailsViewController.h"
#import "PMMeetingAnnotation.h"

@interface ViewController () <MKMapViewDelegate, UIPopoverPresentationControllerDelegate>

@property (strong, nonatomic) NSMutableArray *studentsArray;
@property (strong, nonatomic) id <MKAnnotation> meetingAnnotation;

@property (strong, nonatomic) CLGeocoder *geoCoder;
@property (strong, nonatomic) MKDirections *directions;

@property (strong, nonatomic) UIPopoverPresentationController *popover;

@property (weak, nonatomic) IBOutlet UILabel *smallLabel;
@property (weak, nonatomic) IBOutlet UILabel *midleLabel;
@property (weak, nonatomic) IBOutlet UILabel *largeLabel;
@property (weak, nonatomic) IBOutlet UIView *distanceView;


@end

static const double smallCircle = 500.f;
static const double midleCircle = 1000.f;
static const double largeCircle = 1500.f;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.distanceView.hidden = YES;
    
    self.studentsArray = [NSMutableArray array];
    NSInteger count = arc4random() % 31 + 10;
    
    for (int i = 0; i < count; i++) {
        [self.studentsArray addObject: [PMStudent randomStudent]];
    }
    
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAdd
                                                                               target: self
                                                                               action: @selector(actionAdd:)];
    
    UIBarButtonItem *addMeatingButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAction
                                                                               target: self
                                                                               action: @selector(actionAddMeeting:)];
    
    UIBarButtonItem *goToMeatingButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemPlay
                                                                                      target: self
                                                                                      action: @selector(actionGoToMeeting:)];
    
    self.navigationItem.rightBarButtonItems = @[addButton, addMeatingButton, goToMeatingButton];
    
    addMeatingButton.enabled = NO;
    goToMeatingButton.enabled = NO;
    
    self.geoCoder = [[CLGeocoder alloc] init];
    
}

- (void)dealloc
{
    if ([self.geoCoder isGeocoding]) {
        [self.geoCoder cancelGeocode];
    }
    
    if ([self.directions isCalculating]) {
        [self.directions cancel];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Help Methods

- (void) addCirclesOnMapView: (MKMapView *) mapView  toAnnotationView: (MKAnnotationView *) annotationView {
    
    MKCircle *circle1 = [MKCircle circleWithCenterCoordinate: annotationView.annotation.coordinate radius: smallCircle];
    MKCircle *circle2 = [MKCircle circleWithCenterCoordinate: annotationView.annotation.coordinate radius: midleCircle];
    MKCircle *circle3 = [MKCircle circleWithCenterCoordinate: annotationView.annotation.coordinate radius: largeCircle];

    [mapView addOverlays: @[circle1, circle2, circle3]];
}

- (void) calculateDistanceToAnnotation: (id <MKAnnotation>) annotation {
    
    CLLocation *meetingLocation = [[CLLocation alloc] initWithLatitude: annotation.coordinate.latitude
                                                             longitude: annotation.coordinate.longitude];
    
    int smallCount, midleCount, largeCount;
    smallCount = midleCount = largeCount = 0;
    
    for (PMStudent *student in self.studentsArray) {
        
        CLLocation *studentLocation = [[CLLocation alloc] initWithLatitude: student.coordinate.latitude
                                                                 longitude: student.coordinate.longitude];
        
        double distance = [meetingLocation distanceFromLocation: studentLocation];
        
        if (distance <= smallCircle) {
            smallCount++;
        } else if (distance <= midleCircle) {
            midleCount++;
        } else if (distance <= largeCircle) {
            largeCount++;
        }
        
        student.distance = distance;
    }
    
    self.smallLabel.text = [NSString stringWithFormat: @"%d", smallCount];
    self.midleLabel.text = [NSString stringWithFormat: @"%d", midleCount];
    self.largeLabel.text = [NSString stringWithFormat: @"%d", largeCount];
}

- (BOOL) randomBoolWithYesPercentage: (int) percentage {
    int rand = arc4random() % 101;
    NSLog(@"%i < %i", rand, percentage);
    return rand < percentage;
}

#pragma mark - Actions

- (void) actionGoToMeeting: (UIBarButtonItem *) sender {
 
    if ([self.directions isCalculating]) {
        [self.directions cancel];
    }
    
    MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
    
    MKPlacemark *sourcePlacemark = [[MKPlacemark alloc] initWithCoordinate: self.meetingAnnotation.coordinate];
    request.source = [[MKMapItem alloc] initWithPlacemark: sourcePlacemark];
    
    for (PMStudent *student in self.studentsArray) {
        
        BOOL isGoing = NO;
        
        if (student.distance == 0) {
            continue;
        } else {
            if (student.distance <= smallCircle) {
                isGoing = [self randomBoolWithYesPercentage: 90];
            } else if (student.distance <= midleCircle) {
                isGoing = [self randomBoolWithYesPercentage: 50];
            } else if (student.distance <= largeCircle) {
                isGoing = [self randomBoolWithYesPercentage: 10];
            } else {
                isGoing = [self randomBoolWithYesPercentage: 1];
            }
        }
        
        if (isGoing) {
            MKPlacemark *destinationPlacemark = [[MKPlacemark alloc] initWithCoordinate: student.coordinate];
            request.destination = [[MKMapItem alloc] initWithPlacemark: destinationPlacemark];
            
            request.transportType = MKDirectionsTransportTypeAny;
            request.requestsAlternateRoutes = YES;
            
            self.directions = [[MKDirections alloc] initWithRequest: request];
            
            [self.directions calculateDirectionsWithCompletionHandler:^(MKDirectionsResponse * _Nullable response, NSError * _Nullable error) {
                
                if (error) {
                    NSLog(@"Error: %@", [error localizedDescription]);
                } else if ([response.routes count] == 0) {
                    NSLog(@"Error: No routes found");
                } else {
                    
                    NSMutableArray *array = [NSMutableArray array];
                    
                    for (MKRoute *route in response.routes) {
                        [array addObject: route.polyline];
                    }
                    
                    [self.mapView addOverlays: array level: MKOverlayLevelAboveLabels];
                }
            }];
            
            
            
        } else {
            
            [[self.mapView viewForAnnotation: student] setAlpha: 0.5f];
            NSLog(@"%@ NOT going", student.title);
        }
    }
}

- (void) actionAddMeeting: (UIBarButtonItem *) sender {
    
    [[self.navigationItem.rightBarButtonItems objectAtIndex: 2] setEnabled: YES];

    PMMeetingAnnotation *annotation = [[PMMeetingAnnotation alloc] init];
    
    annotation.title = @"Meating";
    annotation.subtitle = @"Meet here";
    annotation.coordinate = self.mapView.region.center;
    
    [self.mapView addAnnotation: annotation];
    
    self.meetingAnnotation = annotation;
    
    [self calculateDistanceToAnnotation: annotation];
    
    self.distanceView.hidden = NO;
    
}

- (void) actionAdd: (UIBarButtonItem *) sender {
    
    [[self.navigationItem.rightBarButtonItems objectAtIndex: 1] setEnabled: YES];
    
    for (PMStudent *student in self.studentsArray) {
        [self.mapView addAnnotation: student];
    }
    
    //ZOOM
    MKMapRect zoomRect = MKMapRectNull;
    
    for (id <MKAnnotation> annotation in self.mapView.annotations) {
        
        CLLocationCoordinate2D location = annotation.coordinate;
        MKMapPoint center = MKMapPointForCoordinate(location);
        
        static double delta = 2000;
        
        MKMapRect rect = MKMapRectMake(center.x - delta, center.y - delta, delta * 2, delta * 2);
        
        zoomRect = MKMapRectUnion(zoomRect, rect);
    }
    
    zoomRect = [self.mapView mapRectThatFits: zoomRect];
    
    [self.mapView setVisibleMapRect: zoomRect
                        edgePadding: UIEdgeInsetsMake(20, 20, 20, 20)
                           animated: YES];
}

- (void) actionDescription: (UIButton *) sender {
    
    MKAnnotationView *annotationView = [sender superAnnotationView];

    if (!annotationView) {
        return;
    }
    
    CLLocationCoordinate2D coordinate = annotationView.annotation.coordinate;
    CLLocation *location = [[CLLocation alloc] initWithLatitude: coordinate.latitude
                                                      longitude: coordinate.longitude];
    
    if ([self.geoCoder isGeocoding]) {
        [self.geoCoder cancelGeocode];
    }
    
    PMDetailsViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier: @"PMDetailsViewController"];
    
    vc.preferredContentSize = CGSizeMake(300, 350);
    vc.modalPresentationStyle = UIModalPresentationPopover;
    self.popover = vc.popoverPresentationController;
    self.popover.delegate = self;
    self.popover.sourceView = sender;
    self.popover.sourceRect = sender.frame;
    
    [self.geoCoder reverseGeocodeLocation: location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"%@", [error localizedDescription]);
        } else {
            if ([placemarks count] > 0) {
                
                CLPlacemark *placeMark = [placemarks firstObject];
                
                vc.city = [NSString stringWithFormat:@"%@", placeMark.locality];
                vc.country = [NSString stringWithFormat:@"%@", placeMark.country];
                if (placeMark.thoroughfare != NULL && placeMark.subThoroughfare != NULL) {
                    vc.address = [NSString stringWithFormat:@"%@, %@", placeMark.thoroughfare, placeMark.subThoroughfare];
                } else if(placeMark.thoroughfare != NULL) {
                    vc.address = [NSString stringWithFormat:@"%@", placeMark.thoroughfare];
                }
            } else {
                NSLog(@"No Placemarks found");
            }
        }
        
        vc.name = annotationView.annotation.title;
        vc.birth = annotationView.annotation.subtitle;
        
        for (PMStudent *student in self.studentsArray) {
            if ([student isEqual: annotationView.annotation]) {
                vc.gender = student.gender ? @"Female" : @"Male";
            }
        }
        
        [self presentViewController: vc animated: YES completion: nil];
        
    }];
}

#pragma mark - MKMapViewDelegate

- (nullable MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    
    if ([annotation isKindOfClass: [MKUserLocation class]]) {
        return nil;
    } else if ([annotation isKindOfClass: [PMStudent class]]) {
        
        static NSString *identifier = @"Annotation";
        
        MKAnnotationView *annotationView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier: identifier];
        
        if (!annotationView) {
            annotationView = [[MKAnnotationView alloc] initWithAnnotation: annotation reuseIdentifier: identifier];
            annotationView.image = [(PMStudent *)annotation image];
            annotationView.canShowCallout = YES;
        } else {
            annotationView.annotation = annotation;
        }
        
        UIButton *descriptionButton = [UIButton buttonWithType: UIButtonTypeDetailDisclosure];
        [descriptionButton addTarget: self action: @selector(actionDescription:) forControlEvents: UIControlEventTouchUpInside];
        annotationView.rightCalloutAccessoryView = descriptionButton;
        
        return annotationView;
    } else {
        
        static NSString *identifier = @"Meating";
        
        MKAnnotationView *annotationView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier: identifier];
        
        if (!annotationView) {
            annotationView = [[MKAnnotationView alloc] initWithAnnotation: annotation reuseIdentifier: identifier];
            annotationView.image = [UIImage imageNamed: @"Images/meating.png"];
            
            annotationView.canShowCallout = YES;
            annotationView.draggable = YES;
        } else {
            annotationView.annotation = annotation;
        }
        
        [self addCirclesOnMapView: mapView toAnnotationView: annotationView];
        
        annotationView.highlighted = YES;
        
        return annotationView;
    }
}

- (void)mapView:(MKMapView *)mapView annotationView: (MKAnnotationView *) view didChangeDragState:(MKAnnotationViewDragState) newState fromOldState: (MKAnnotationViewDragState) oldState {
    
    if (newState == MKAnnotationViewDragStateStarting) {
        [mapView removeOverlays: mapView.overlays];
        
        for (PMStudent *student in self.studentsArray) {
            [[self.mapView viewForAnnotation: student] setAlpha: 1.f];
        }
    }
    
    if (newState == MKAnnotationViewDragStateEnding) {
        
        [self addCirclesOnMapView: mapView toAnnotationView: view];
        
        [self calculateDistanceToAnnotation: view.annotation];

        [view setDragState: MKAnnotationViewDragStateNone animated: YES];
    }
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay  {
    
    if ([overlay isKindOfClass:[MKCircle class]]) {
        
        MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithOverlay: overlay];
        renderer.lineWidth = 1.2f;
        renderer.strokeColor = [UIColor colorWithRed: 0.f green: 0.5f blue: 1.f alpha: 1.f];
        renderer.fillColor = [UIColor colorWithRed: 0.f green: 0.5f blue: 1.f alpha: 0.2f];
        
        return renderer;
        
    } else if ([overlay isKindOfClass:[MKPolyline class]]) {
        
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithOverlay: overlay];
        renderer.lineWidth = 2.f;
        renderer.strokeColor = [UIColor colorWithRed: 0.f green: 1.f blue: 0.5f alpha: 0.9f];
        
        return renderer;
    }
    return nil;
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (void) popoverPresentationControllerDidDismissPopover: (UIPopoverPresentationController *) popoverPresentationController {
    
    self.popover = nil;
}

- (UIModalPresentationStyle) adaptivePresentationStyleForPresentationController: (UIPresentationController *) controller {
    
    return UIModalPresentationNone;
}
@end
