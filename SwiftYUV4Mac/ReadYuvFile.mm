//
//  ReadYuvFile.m
//  SwiftYUV
//
//  Created by VislaNiap on 2021/4/16.
//

#import "ReadYuvFile.h"
#import <MetalKit/MetalKit.h>
#import "SwiftYUV4Mac-Swift.h"
#import <CoreFoundation/CoreFoundation.h>
@interface ReadYuvFile ()
{
   
}
@end

@implementation ReadYuvFile
- (void)read:(MainController*)caller
{
    CVPixelBufferRef pixelBuffer = nullptr;
    NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
    int width = 640;
    int height = 360;
    uint8_t *yuv_data = (uint8_t *)malloc((int)(width*height*1.5));
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          width,
                                          height,
                                          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                                          (__bridge CFDictionaryRef)(pixelAttributes),
                                          &pixelBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer,0);
    unsigned char *yDestPlane = (unsigned char*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
//    size_t yStep = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    NSString * path = [NSBundle.mainBundle pathForResource:@"video" ofType:@"yuv"];
    FILE *fp1=fopen(path.UTF8String,"rw");
    fread(yuv_data,1,width*height*1.5,fp1);
    fclose(fp1);
    const unsigned char *y_ch0 = yuv_data ;
    memcpy(yDestPlane, y_ch0, width*height);
//    const uint8_t *y_ch1 = yuv_data + width * height;
//    unsigned char *uDestPlane =(unsigned char*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
//    memcpy(uDestPlane, y_ch1, width*height/4 );
//    const uint8_t *y_ch2 = yuv_data + int(width * height * 1.25);
//    unsigned char *vDestPlane =(unsigned char*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2);
//    memcpy(vDestPlane, y_ch2, width*height/4 );
//    const uint8_t *y_ch1 = yuv_data + width * height;
//    const uint8_t *y_ch2 = yuv_data + int(width * height * 1.25);
//    for(int i=0;i<height;i++){
//        memcpy(yDestPlane+i*yStep, y_ch0+i*width, width );
//    }
//    size_t uStep = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
//    unsigned char *uDestPlane =(unsigned char*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
//    for(int i=0;i<height/2;i++){
//        memcpy(uDestPlane+i*uStep, y_ch1+i*width/2, width/2 );
//    }
//    size_t vStep = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
//    unsigned char *vDestPlane =(unsigned char*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
//    for(int i=0;i<height/2;i++){
//        memcpy(vDestPlane+i*uStep, y_ch2+i*width/2, width/2 );
//    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    //[self imageFromPixelBuffer:pixelBuffer from:caller];
    [caller renderWithPixcelBuffer:pixelBuffer];
}

-  (void)imageFromPixelBuffer:(CVPixelBufferRef)pixelBufferRef from:(MainController*)caller {
    CVImageBufferRef imageBuffer =  pixelBufferRef;
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBufferRef];
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext createCGImage:coreImage
                                                       fromRect:CGRectMake(0, 0, width, height)];
    NSImage *finalImage =  [[NSImage alloc] initWithCGImage:videoImage size:CGSizeMake(width,height)];
    [caller renderImageWithImage:finalImage];
}



@end
