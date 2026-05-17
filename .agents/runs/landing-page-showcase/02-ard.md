# Architecture Requirements Document: Landing Page Showcase

## Decisions & Structure

1. **Zero-Build Deployability**: The website must remain fully static and load instantly from any standard static file hosting (e.g. GitHub Pages). We will use Tailwind CSS loaded via CDN and write modern vanilla JavaScript inside `script` blocks in `docs/index.html`.
2. **Interactive CSS Mockups**: Rather than loading heavy external files or static image screenshots, the macOS mockup, menu bar, camera notch, Spill panel, Xcode window, and Agent Cat terminal will be authored using pure, lightweight, responsive semantic HTML/CSS elements.
3. **Scroll-Snap & IntersectionObserver**: We will implement a responsive CSS scroll-snap framework. A custom `IntersectionObserver` will track which section is currently active and update both the side indicator dots and the floating header menu.
4. **Fluid Layout System**: Use flexbox and grid layouts combined with Tailwind's fluid spacing tokens and responsive modifiers (`sm:`, `md:`, `lg:`) to ensure every pixel scales perfectly down to a 320px mobile viewport and up to a 4K display.
