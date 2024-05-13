JPEG File Interchange Format (JFIF)
===================================
The JPEG File Interchange Format (JFIF) is an image file format standard published as ITU-T
Recommendation T. 871 and ISO/IEC 10918-5. It defines supplementary specifications for the
container format that contains the image data encoded with the JPEG algorithm.

The base specifications for a JPEG container format are defined in the JPEG standard,
known as JPEG Interchange Format (JIF). JFIF builds over JIF to solve some of JIF's limitations,
including unnecessary complexity, component sample registration, resolution, aspect ratio,
and color space. JFIF also defines a number of details that are left unspecified by JPEG standard.

### JFIF structure
A JFIF file consists of a sequence of markers or marker segments. Some markers stand alone,
but most indicate the start of a marker segment that contains data bytes according to the following pattern:

```marker
0xFF 0xXX
```
Each marker consists of two bytes:
* `0xFF` byte to indicate the start of the marker.
* `0xXX` byte which is not equal to `0x00` or `0xFF` that specifies the type of the marker.

```optional
[length] [length] [data bytes]
```
Some segments also have payload after the marker with a length specified in the following 16 bits.
(The length includes the length bytes too.)

### Segments
Here I would like to go deep into the structure of individual segments that can be found in JPEG files.

#### Start of Image
* name: SOI
* marker: 0xFF 0xD8
* payload: -
* description: indicates the start of the image.

#### Quantization Table
* name: DQT
* marker: 0xFF 0xDB
* payload: variable
* description: defines quantization tables for the image.

Source: https://en.wikipedia.org/wiki/JPEG_File_Interchange_Format

