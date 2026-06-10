# SplineExtractor

Spline extraction and container instancing tool for imported DWG spline objects.

## Entry script

- [`SplineExtractor.ms`](SplineExtractor.ms)

## Macro

- `_DwgTools_SplineExtractor`

## Overview

- Splits spline objects into separate spline elements.
- Uses container bounding boxes and pivot positions to attach nested child splines into container shapes.
- Can replace matching containers with instances to reduce duplicate geometry and simplify repeated architectural elements.

## Repository navigation

- [Back to main README](../../README.md)
