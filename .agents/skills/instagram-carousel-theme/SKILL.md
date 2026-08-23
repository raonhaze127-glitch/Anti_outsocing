---
name: instagram-carousel-theme
description: Guides the creation and styling of premium Instagram carousels (1080x1350 px) with exact typography, color palettes, and container components.
---

# Premium Instagram Carousel Design System

Use this guide to construct highly legible, visually appealing 8-slide Instagram carousels (4:5 vertical ratio, 1080 × 1350 px) optimized for mobile viewing.

## 1. Dimensional Standard
* **Canvas Size**: 1080 × 1350 px (4:5 ratio)
* **Output Format**: PNG
* **Safe Area Margin**: 
  - **1:1 Grid Safe Area**: Y-axis `170px ~ 1170px`, X-axis `150px ~ 930px` (max width `780px`).
  - Top/Bottom 170px padding to avoid Instagram profile grid (1080x1080px 1:1 crop) text clipping.

## 2. Color System
* **Dark Navy (Main BG/Header)**: `#0D1B3E`
* **Main Blue (Primary Accent)**: `#1F5ADB`
* **Sub Orange (Highlights/Numbers)**: `#F5A623` / `#F4B942`
* **Soft Light Blue (Light Card BG)**: `#EAF0FB`
* **Soft Light Gray (Neutral Card BG)**: `#F8F9FA`
* **Pure White (Secondary BG)**: `#FFFFFF`
* **Warning Red (Countdown/Alert BG)**: `#E53E3E` or `#FEF2F2` (soft border `#EF4444`)

## 3. Typography Tokens (Legibility Optimized & Grid Fit)
* **Cover Main Title**: `68px` ~ `70px` (Pretendard ExtraBold/Bold, line-height: 1.25, max-width: 780px)
* **Cover Sub Title**: `68px` ~ `70px` (Pretendard Bold, color: `#F4B942`)
* **Cover Status Badge**: Positioned at top-center (`top: 170px`), `24px ~ 26px` Bold
* **Section Title**: `52px` ~ `56px` (Pretendard Bold, color: `#0D1B3E` or `#FFFFFF`)
* **Card Primary Text**: `28px` ~ `32px` (Pretendard Semibold/Regular)
* **Notice Header**: `26px` (Pretendard Bold)
* **Notice Body**: `24px` (Pretendard Regular, line-height: 1.4)
* **CTA Title**: `32px` ~ `36px` (Pretendard Bold)
* **CTA Sub/Items**: `24px` ~ `28px` (Pretendard Regular/Bold)
* **Watermark Account**: `20px ~ 22px` (Pretendard Bold, color: `#F4B942` or `#1F5ADB`, bottom: 45px, right: 150px)
* **Footer Text**: `20px ~ 22px` (Pretendard Regular, opacity: 70%, bottom: 45px, left: 150px)


## 4. Reusable Layout Blocks
1. **Grids**: Use 3-column or 2-column flexbox/grid for card lists (`gap: 14px` to `20px` to fit 960px content width).
2. **Timeline Steps**: Vertical lines at `x: 180px` with left date label (`width: 160px`) and right step description boxes (`margin-left: 20px`).
3. **Double Panels**: Side-by-side or stacked panels with 20px gaps and border radius of `20px` to `24px`.
4. **Notice Boxes**: Light background color card with a thick left-accent border (`border-left: 6px solid <color>`) and padding of `22px 30px`.
