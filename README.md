# BadFetch

A web fetcher that impersonates Chrome, Firefox, or curl. Sends concurrent fetch requests via Dart isolates. Built with Dart + C3, uses WinHTTP directly. Total ~7 MB. Windows only.

## Building

```bash
cd engine && c3c build -O2 && cd ..
copy /Y engine\build\engine.dll .
dart pub get
dart compile exe bin\bf.dart -o bf.exe
```

## Usage

Single URL:

```
bf https://www.google.com
```

Firefox mode:

```
bf --firefox https://www.google.com
```

Curl mode:

```
bf --curl https://www.google.com
```

Multiple URLs:

```
bf -j url1 url2 url3
```

URLs from a file (one per line):

```
https://www.google.com
https://www.example.com
https://www.github.com
```

```
bf -f urls.txt
```

Update Chrome version (default 131, fetches current from Chromium Dash):

```
bf --update-versions
```
