import cv2
import numpy as np
import os

def write_to_framebuffer(frame):
    """
    Writes a given frame (image) to the framebuffer (/dev/fb0).
    The frame must be resized to match the framebuffer resolution.
    """
    framebuffer_path = "/dev/fb0"

    # Ensure the framebuffer exists
    if not os.path.exists(framebuffer_path):
        print(f"Error: Framebuffer {framebuffer_path} not found.")
        return

    # Get framebuffer resolution (assuming 720p for this example; adjust as needed)
    fb_width = 1280
    fb_height = 720

    # Resize the frame to match the framebuffer resolution
    resized_frame = cv2.resize(frame, (fb_width, fb_height))

    # Convert the frame to BGR565 format (5 bits Blue, 6 bits Green, 5 bits Red)
    bgr565_frame = cv2.cvtColor(resized_frame, cv2.COLOR_BGR2BGR565)

    try:
        # Write the frame to the framebuffer
        with open(framebuffer_path, 'wb') as fb:
            fb.write(bgr565_frame.tobytes())
    except IOError as e:
        print(f"Error writing to framebuffer: {e}")

def main():
    # Load the pre-trained Cascade Classifier
    cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    face_cascade = cv2.CascadeClassifier(cascade_path)

    # Initialize video capture (0 = default camera)
    video_capture = cv2.VideoCapture(0)

    if not video_capture.isOpened():
        print("Error: Unable to access the camera.")
        return

    print("Press 'q' to quit.")

    while True:
        # Read the current frame from the camera
        ret, frame = video_capture.read()
        if not ret:
            print("Error: Unable to read frame.")
            break

        # Convert the image to grayscale
        gray_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Detect faces in the frame
        faces = face_cascade.detectMultiScale(
            gray_frame, 
            scaleFactor=1.1, 
            minNeighbors=5, 
            minSize=(30, 30)
        )

        # Draw rectangles around detected faces
        for (x, y, w, h) in faces:
            cv2.rectangle(frame, (x, y), (x + w, y + h), (255, 0, 0), 2)

        # Write the video frame with detected faces to the framebuffer
        write_to_framebuffer(frame)

        # Break the loop if 'q' is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Release resources
    video_capture.release()
    print("Exiting...")

if __name__ == "__main__":
    main()
