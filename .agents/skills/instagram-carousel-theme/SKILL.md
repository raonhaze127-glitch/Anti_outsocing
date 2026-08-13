---
name: instagram-carousel-theme
description: Guides the creation and styling of premium Instagram carousels (1080x1350 px) with exact typography, color palettes, and container components.
---

# Premium Instagram Carousel Design System

Use this guide to construct highly legible, visually appealing 8-slide Instagram carousels (4:5 vertical ratio, 1080 × 1350 px) optimized for mobile viewing.

## 1. Dimensional Standard
* **Canvas Size**: 1080 × 1350 px
* **Output Format**: PNG
* **Safe Area Margin**: 60px padding from left/right/top/bottom edges.

## 2. Color System
* **Dark Navy (Main BG/Header)**: `#0D1B3E`
* **Main Blue (Primary Accent)**: `#1F5ADB`
* **Sub Orange (Highlights/Numbers)**: `#F5A623`
* **Soft Light Blue (Light Card BG)**: `#EAF0FB`
* **Soft Light Gray (Neutral Card BG)**: `#F8F9FA`
* **Pure White (Secondary BG)**: `#FFFFFF`
* **Warning Red (Countdown/Alert BG)**: `#E53E3E` or `#FEF2F2` (soft border `#EF4444`)

## 3. Typography Tokens (Legibility Optimized)
* **Cover Main Title**: `90px` (Pretendard Bold, line-height: 1.25)
* **Cover Sub Title**: `60px` (Pretendard Bold, color: `#F5A623`)
* **Section Title**: `52px` ~ `56px` (Pretendard Bold, color: `#0D1B3E` or `#FFFFFF`)
* **Card Primary Text**: `30px` ~ `34px` (Pretendard Semibold/Regular)
* **Notice Header**: `28px` (Pretendard Bold)
* **Notice Body**: `24px` (Pretendard Regular, line-height: 1.4)
* **CTA Title**: `60px` (Pretendard Bold)
* **CTA Sub/Items**: `30px` ~ `38px` (Pretendard Regular/Bold)
* **Watermark Account**: `14px` (Pretendard Regular, opacity: 70%, bottom: 40px, right: 60px)
* **Footer Text**: `12px` (Pretendard Regular, opacity: 50%, bottom: 40px, left: 60px)

## 4. Reusable Layout Blocks
1. **Grids**: Use 3-column or 2-column flexbox/grid for card lists (`gap: 14px` to `20px` to fit 960px content width).
2. **Timeline Steps**: Vertical lines at `x: 180px` with left date label (`width: 160px`) and right step description boxes (`margin-left: 20px`).
3. **Double Panels**: Side-by-side or stacked panels with 20px gaps and border radius of `20px` to `24px`.
4. **Notice Boxes**: Light background color card with a thick left-accent border (`border-left: 6px solid <color>`) and padding of `22px 30px`.
