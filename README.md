# Guide:
- Either install Xcode and download repo and run project or install from app store.
- Upon running application, the icon will show up in top right corner of mac bar.
- You can either capture current screen, quit application, or switch languages used for translation.
- Upon capturing screen, you can toggle at the bottom whether to find definitions of words or the entire line. there is a close button in the bottom right corner.
#
# How I Made It:
- I used Apple's Vision Framework to perform OCR on the image and retrieve characters and corresponding bounding boxes.
- Before Apple's release of the Translation API, I used MySQL (sqlite3 in Xcode) to store chinese dictionary into a database, search characters and retrieve pronounciation and definitions corresponding to those characters.
- After its release I used Apple's new Translation API to make it faster, more code efficient, and not needing every language's dictionary stored into a database.
- For the UI I used Apple's Cocoa Kit (very tedious and irritative to use by the way, do not recommend using) (on that note, even though I think Swift is a great langauge, after my ios app and screen app I opted never to use Swift again for its terrible UI)
- #
- More information on classes and bits of code is explained in comments in my code itself.
