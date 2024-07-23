A Realtime Object Detection application. This application utilizes MobileNet SSD and Coco dataset. The application also calculates the distance between Object
and user.Furthermore, it also estimates the position of detected object.

For calculation of distance, the following formula is used:


double distanceMm = (focalLengthMm * objectHeightMm * imageHeight) / (boundingBoxHeightPixels * sensorHeightMm);

For estimating the position of object, following function is used

double calculateHorizontalDistance(double boundingBoxX) {
double screenCenterX = imageWidth / 2;
double objectCenterX = boundingBoxX + (imageWidth * 0.5);
return (objectCenterX - screenCenterX) / screenCenterX;
}

String getObjectDirection(double horizontalDistance) {
if (horizontalDistance < -0.33) {
return "left";
} else if (horizontalDistance > 0.33) {
return "right";
}    else {
return "center";
}
}
