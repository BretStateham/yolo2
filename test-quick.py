"""Quick Playwright test - check key links only."""
from playwright.sync_api import sync_playwright
import os

HTML = "file:///" + os.path.join(os.getcwd(), "chat-history.html").replace("\\", "/")

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1280, "height": 800})
    page.goto(HTML, wait_until="domcontentloaded")
    page.wait_for_timeout(1000)

    # Check ALL blocks are inside .main
    info = page.evaluate("""() => {
        const main = document.querySelector('.main');
        const allBlocks = document.querySelectorAll('.block, .tool-group');
        let outside = 0;
        for (let b of allBlocks) {
            if (!main.contains(b)) outside++;
        }
        return { total: allBlocks.length, outside: outside, inside: allBlocks.length - outside };
    }""")
    print(f"Blocks: {info['total']} total, {info['inside']} inside .main, {info['outside']} outside")
    if info["outside"] > 0:
        print("  *** BLOCKS ESCAPING .main CONTAINER ***")

    # Test key nav links
    errors = []
    for i in [1, 10, 18, 19, 20, 30, 43]:
        page.click(f'a[href="#user-{i}"]')
        page.wait_for_timeout(300)
        sb = page.locator(".sidebar").bounding_box()
        sidebar_ok = sb and sb["width"] > 100
        el = page.locator(f"#user-{i}")
        box = el.bounding_box() if el.count() > 0 else None
        in_view = box and box["x"] >= 250
        body = page.evaluate("""(id) => {
            const el = document.getElementById(id);
            if (!el) return "NOT_FOUND";
            const b = el.querySelector(".block-body");
            return b ? b.textContent.substring(0,40) : "NO_BODY";
        }""", f"user-{i}")
        status = "OK" if (sidebar_ok and in_view) else f"FAIL sidebar={sidebar_ok} inView={in_view}"
        if status != "OK":
            errors.append(f"user-{i}: {status}")
        x_val = box["x"] if box else "?"
        print(f"  user-{i}: {status} x={x_val} body=[{body}]")

    # Direct navigation tests
    for i in [19, 43]:
        page.goto(HTML + f"#user-{i}", wait_until="domcontentloaded")
        page.wait_for_timeout(1000)
        sb = page.locator(".sidebar").bounding_box()
        sidebar_ok = sb and sb["width"] > 100
        result = "OK" if sidebar_ok else "GONE"
        print(f"  Direct #user-{i}: sidebar={result}")
        if not sidebar_ok:
            errors.append(f"Direct #user-{i}: sidebar gone")

    # Screenshot
    page.goto(HTML + "#user-43", wait_until="domcontentloaded")
    page.wait_for_timeout(1000)
    page.screenshot(path=".debug-images/pw-user43.png", full_page=False)
    print("Screenshot saved to .debug-images/pw-user43.png")

    if errors:
        print(f"\nFAILED: {len(errors)} error(s)")
        for e in errors:
            print(f"  X {e}")
    else:
        print("\nALL TESTS PASSED")
    browser.close()
