"""Playwright test for chat-history.html layout and scrolling."""
import os, sys
from playwright.sync_api import sync_playwright

HTML_PATH = os.path.join(os.path.dirname(__file__), "chat-history.html")
FILE_URL = "file:///" + HTML_PATH.replace("\\", "/")

def test():
    errors = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1280, "height": 800})

        # TEST 1: Basic load
        print("TEST 1: Load page without hash...")
        page.goto(FILE_URL, wait_until="domcontentloaded")
        page.wait_for_timeout(500)

        sidebar = page.locator(".sidebar")
        main = page.locator(".main")

        sb_box = sidebar.bounding_box()
        main_box = main.bounding_box()
        print(f"  Sidebar: {sb_box}")
        print(f"  Main: {main_box}")

        if not sb_box or sb_box["width"] < 100:
            errors.append("Sidebar not visible on basic load")
        if not main_box or main_box["width"] < 400:
            errors.append("Main area too narrow on basic load")

        # TEST 2: Click sidebar link to user-1 (should work)
        print("TEST 2: Click nav link to user-1...")
        page.click('a[href="#user-1"]')
        page.wait_for_timeout(500)
        sb_box2 = sidebar.bounding_box()
        main_box2 = main.bounding_box()
        print(f"  Sidebar after click user-1: {sb_box2}")
        if not sb_box2 or sb_box2["width"] < 100:
            errors.append("Sidebar disappeared after clicking user-1")

        # TEST 3: Click sidebar link to user-19 (was breaking before)
        print("TEST 3: Click nav link to user-19...")
        page.click('a[href="#user-19"]')
        page.wait_for_timeout(500)
        sb_box3 = sidebar.bounding_box()
        main_box3 = main.bounding_box()
        print(f"  Sidebar after click user-19: {sb_box3}")
        print(f"  Main after click user-19: {main_box3}")
        if not sb_box3 or sb_box3["width"] < 100:
            errors.append("Sidebar disappeared after clicking user-19")

        # Check user-19 is visible
        u19 = page.locator("#user-19")
        if u19.count() == 0:
            u19 = page.locator('[data-msg="user-19"]')
        if u19.count() > 0:
            u19_box = u19.bounding_box()
            print(f"  user-19 element: {u19_box}")
            if u19_box:
                # Check it's in the viewport
                if u19_box["y"] < 0 or u19_box["y"] > 800:
                    errors.append(f"user-19 not in viewport (y={u19_box['y']})")
            else:
                errors.append("user-19 has no bounding box")
        else:
            errors.append("user-19 element not found")

        # TEST 4: Click sidebar link to user-43 (last message)
        print("TEST 4: Click nav link to user-43...")
        page.click('a[href="#user-43"]')
        page.wait_for_timeout(500)
        sb_box4 = sidebar.bounding_box()
        main_box4 = main.bounding_box()
        print(f"  Sidebar after click user-43: {sb_box4}")
        print(f"  Main after click user-43: {main_box4}")
        if not sb_box4 or sb_box4["width"] < 100:
            errors.append("Sidebar disappeared after clicking user-43")

        # TEST 5: Direct URL navigation with hash
        print("TEST 5: Direct navigate to #user-43...")
        page.goto(FILE_URL + "#user-43", wait_until="domcontentloaded")
        page.wait_for_timeout(1000)
        sb_box5 = sidebar.bounding_box()
        main_box5 = main.bounding_box()
        print(f"  Sidebar on direct #user-43: {sb_box5}")
        print(f"  Main on direct #user-43: {main_box5}")
        if not sb_box5 or sb_box5["width"] < 100:
            errors.append("Sidebar not visible on direct #user-43 navigation")

        # TEST 6: Can scroll to bottom of page
        print("TEST 6: Scroll to bottom...")
        page.goto(FILE_URL, wait_until="domcontentloaded")
        page.wait_for_timeout(500)

        # Find the scrollable element and scroll it
        scroll_height = page.evaluate("""() => {
            // Try .main first, then document
            const main = document.querySelector('.main');
            if (main && main.scrollHeight > main.clientHeight) {
                return { el: '.main', scrollHeight: main.scrollHeight, clientHeight: main.clientHeight };
            }
            return { el: 'document', scrollHeight: document.documentElement.scrollHeight, clientHeight: document.documentElement.clientHeight };
        }""")
        print(f"  Scroll info: {scroll_height}")

        # Scroll to bottom
        can_scroll = page.evaluate("""() => {
            const main = document.querySelector('.main');
            const el = (main && main.scrollHeight > main.clientHeight) ? main : document.documentElement;
            el.scrollTop = el.scrollHeight;
            return { finalScrollTop: el.scrollTop, maxScroll: el.scrollHeight - el.clientHeight };
        }""")
        print(f"  Scroll result: {can_scroll}")

        # Check last user block is reachable
        page.click('a[href="#user-43"]')
        page.wait_for_timeout(500)
        u43 = page.locator("#user-43")
        if u43.count() == 0:
            u43 = page.locator('[data-msg="user-43"]')
        if u43.count() > 0:
            u43_box = u43.bounding_box()
            print(f"  user-43 after nav: {u43_box}")
            if u43_box and u43_box["y"] > 800:
                errors.append(f"user-43 not scrolled into view (y={u43_box['y']})")
        else:
            errors.append("user-43 element not found")

        # TEST 7: Sidebar still visible after scrolling
        print("TEST 7: Sidebar visible after scrolling to bottom...")
        sb_box7 = sidebar.bounding_box()
        print(f"  Sidebar: {sb_box7}")
        if not sb_box7 or sb_box7["width"] < 100:
            errors.append("Sidebar disappeared after scrolling to bottom")

        browser.close()

    print("\n" + "=" * 50)
    if errors:
        print(f"FAILED: {len(errors)} error(s)")
        for e in errors:
            print(f"  ✗ {e}")
        sys.exit(1)
    else:
        print("ALL TESTS PASSED ✓")

if __name__ == "__main__":
    test()
