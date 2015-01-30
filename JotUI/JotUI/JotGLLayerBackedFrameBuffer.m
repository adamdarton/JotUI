//
//  JotGLRenderBackedFrameBuffer.m
//  JotUI
//
//  Created by Adam Wulf on 1/29/15.
//  Copyright (c) 2015 Adonit. All rights reserved.
//

#import "JotGLLayerBackedFrameBuffer.h"
#import "JotView.h"

@implementation JotGLLayerBackedFrameBuffer{
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    GLuint viewRenderbuffer;
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    GLuint depthRenderbuffer;

    CGSize initialViewport;
    
    CALayer<EAGLDrawable>* layer;
    
    // YES if we need to present our renderbuffer on the
    // next display link
    BOOL needsPresentRenderBuffer;
    // YES if we should limit to 30fps, NO otherwise
    BOOL shouldslow;
    // helper var to toggle between frames for 30fps limit
    BOOL slowtoggle;
}

@synthesize initialViewport;
@synthesize shouldslow;

-(id) initForLayer:(CALayer<EAGLDrawable>*)_layer{
    if(self = [super init]){
        CheckMainThread;
        layer = _layer;
        [JotGLContext runBlock:^(JotGLContext* context){
            // The pixel dimensions of the backbuffer
            GLint backingWidth;
            GLint backingHeight;
            
            // Generate IDs for a framebuffer object and a color renderbuffer
            glGenFramebuffersOES(1, &framebufferID);
            glGenRenderbuffersOES(1, &viewRenderbuffer);
            
            glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebufferID);
            glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
            // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
            // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
            [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:layer];
            glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
            
            glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
            glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
            
            // For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
            glGenRenderbuffersOES(1, &depthRenderbuffer);
            glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
            glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
            glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
            
            CGRect frame = layer.bounds;
            CGFloat scale = layer.contentsScale;
            
            initialViewport = CGSizeMake(frame.size.width * scale, frame.size.height * scale);
            
            glOrthof(0, (GLsizei) initialViewport.width, 0, (GLsizei) initialViewport.height, -1, 1);
            glViewport(0, 0, (GLsizei) initialViewport.width, (GLsizei) initialViewport.height);
            
            if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
            {
                NSString* str = [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)];
                DebugLog(@"%@", str);
                @throw [NSException exceptionWithName:@"Framebuffer Exception" reason:str userInfo:nil];
            }
            
            glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
            
            [self clear];
        }];
    }
    return self;
}

-(void) setNeedsPresentRenderBuffer{
    needsPresentRenderBuffer = YES;
}

-(void) presentRenderBufferInContext:(JotGLContext*)context{
    [context runBlock:^{
        if(needsPresentRenderBuffer && (!shouldslow || slowtoggle)){
            //        NSLog(@"presenting");
            GLint currBoundFrBuff = -1;
            glGetIntegerv(GL_FRAMEBUFFER_BINDING_OES, &currBoundFrBuff);
            GLint currBoundRendBuff = -1;
            glGetIntegerv(GL_RENDERBUFFER_BINDING_OES, &currBoundRendBuff);
            if(currBoundFrBuff != framebufferID){
                DebugLog(@"gotcha");
            }
            if(currBoundRendBuff != viewRenderbuffer){
                DebugLog(@"gotcha");
            }
            
            glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
            if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES){
                DebugLog(@"%@", [NSString stringWithFormat:@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES)]);
            }

            [context presentRenderbuffer:GL_RENDERBUFFER_OES];

            needsPresentRenderBuffer = NO;
        }
        slowtoggle = !slowtoggle;
        if([context needsFlush]){
//        NSLog(@"flush");
            [context flush];
        }
    }];
}

-(void) clear{
    [JotGLContext runBlock:^(JotGLContext*context){
        //
        // something below here is wrong.
        // and/or how this interacts later
        // with other threads
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, framebufferID);
        glClearColor(0.0, 0.0, 0.0, 0.0);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, 0);
    }];
}

-(void) deleteAssets{
    if(framebufferID){
        glDeleteFramebuffersOES(1, &framebufferID);
        framebufferID = 0;
    }
    if(viewRenderbuffer){
        glDeleteRenderbuffersOES(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
    }
    if(depthRenderbuffer){
        glDeleteRenderbuffersOES(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
}

-(void) dealloc{
    [self deleteAssets];
}

@end
