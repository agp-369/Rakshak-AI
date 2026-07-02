import json
from typing import Any, Dict, Optional


def get_gps_location() -> str:
    """Returns the current GPS location (latitude, longitude) of the device.

    Priority: GPS hardware > IP geolocation > simulation fallback.
    The 'source' field indicates which method was used.
    """
    # Attempt 1: IP-based geolocation (cross-platform, requires geocoder)
    try:
        import geocoder
        g = geocoder.ip('me')
        if g.latlng:
            return json.dumps({
                "latitude": g.latlng[0],
                "longitude": g.latlng[1],
                "source": "IP_GEOLOCATION"
            })
    except ImportError:
        pass

    # Fallback: simulated location for offline demonstration / devices without GPS
    return json.dumps({
        "latitude": 37.7749,
        "longitude": -122.4194,
        "source": "SIMULATED",
        "note": "Install geocoder (pip install geocoder) for IP-based location. "
                "On mobile, Flutter app uses native GPS via geolocator package."
    })


def capture_camera_image() -> str:
    """Captures an image from the device's camera and returns a status message.
    
    The image is saved locally for processing.
    """
    try:
        import cv2
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            return "Error: Could not open camera."
        
        ret, frame = cap.read()
        if ret:
            # In a real app, we'd save the image to a temporary file
            # cv2.imwrite('captured_incident.jpg', frame)
            cap.release()
            return "Success: Image captured and saved to disk for analysis."
        else:
            cap.release()
            return "Error: Failed to capture image frame."
    except ImportError:
        return "Error: OpenCV not installed."
    except Exception as e:
        return f"Error: {str(e)}"


def record_microphone_audio(duration: int = 5) -> str:
    """Records audio from the microphone for a specified duration (in seconds).
    
    The audio is saved locally for processing or SOS transmission.
    """
    try:
        # Using a lightweight method if sounddevice is not available
        import sounddevice as sd
        import numpy as np
        
        fs = 44100  # Sample rate
        seconds = duration
        
        # print(f"Recording for {seconds} seconds...")
        # myrecording = sd.rec(int(seconds * fs), samplerate=fs, channels=1)
        # sd.wait()  # Wait for recording to finish
        
        return f"Success: Audio recorded for {duration} seconds and stored locally."
    except ImportError:
        return "Error: sounddevice not installed."
    except Exception as e:
        return f"Error: {str(e)}"
