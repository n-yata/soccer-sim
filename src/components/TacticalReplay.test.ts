import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { nextTick } from "vue";
import TacticalReplay from "./TacticalReplay.vue";
import { wideOverloadScene } from "@/data/tacticalScenes";

describe("TacticalReplay", () => {
  let wrappers: ReturnType<typeof mount>[];
  let reduced = false;
  let motionChange: ((event: { matches: boolean }) => void) | undefined;
  beforeEach(() => {
    wrappers = [];
    reduced = false;
    vi.useFakeTimers();
    vi.stubGlobal(
      "matchMedia",
      vi.fn(() => ({
        matches: reduced,
        addEventListener: (_: string, callback: typeof motionChange) => {
          motionChange = callback;
        },
        removeEventListener: vi.fn(),
      })),
    );
  });
  afterEach(() => {
    wrappers.forEach((w) => w.unmount());
    vi.useRealTimers();
    vi.unstubAllGlobals();
    motionChange = undefined;
  });
  async function open() {
    const wrapper = mount(TacticalReplay, { props: { scene: wideOverloadScene } });
    wrappers.push(wrapper);
    await wrapper.get('[data-testid="replay-open"]').trigger("click");
    return wrapper;
  }
  async function advance(ms: number) {
    vi.advanceTimersByTime(ms);
    await nextTick();
  }

  it("自動再生せず開き、再生すると位置が動いて最初の解説で自動停止する", async () => {
    const w = await open();
    expect(w.get('[data-testid="replay-step"]').text()).toContain("1 / 5");
    expect(vi.getTimerCount()).toBe(0);
    const before = w.get('[data-player="overlap"]').attributes("transform");
    const ballBefore = w.get('[data-testid="replay-ball"]').attributes("transform");
    await w.get('[data-testid="replay-play"]').trigger("click");
    await advance(1000);
    expect(w.get('[data-player="overlap"]').attributes("transform")).not.toBe(before);
    expect(w.get('[data-testid="replay-ball"]').attributes("transform")).not.toBe(ballBefore);
    await advance(2000);
    expect(w.get('[data-testid="replay-step"]').text()).toContain("2 / 5");
    expect(w.get('[data-testid="replay-ball"]').attributes("transform")).toBe(
      "translate(160, 118)",
    );
    expect(w.get('[data-testid="replay-play"]').text()).toContain("続き");
    expect(w.text()).toContain("守備者を引きつける");
    expect(vi.getTimerCount()).toBe(0);
    await advance(10000);
    expect(w.get('[data-testid="replay-step"]').text()).toContain("2 / 5");
  });

  it("途中停止は座標を保持し、再開後に残りの動きを再生する", async () => {
    const w = await open();
    await w.get('[data-testid="replay-play"]').trigger("click");
    await advance(1000);
    await w.get('[data-testid="replay-play"]').trigger("click");
    const paused = w.get('[data-player="overlap"]').attributes("transform");
    expect(w.find(".replay-pitch__run").exists()).toBe(false);
    expect(w.text()).toContain("移動途中");
    await advance(3000);
    expect(w.get('[data-player="overlap"]').attributes("transform")).toBe(paused);
    await w.get('[data-testid="replay-play"]').trigger("click");
    await advance(2200);
    expect(w.get('[data-testid="replay-step"]').text()).toContain("2 / 5");
  });

  it("前後の解説・最初から・終端を操作でき、カバーと戻す判断まで読める", async () => {
    const w = await open();
    expect(w.get('[data-testid="replay-prev"]').attributes("disabled")).toBeDefined();
    await w.get('[data-testid="replay-next"]').trigger("click");
    await w.get('[data-testid="replay-next"]').trigger("click");
    await w.get('[data-testid="replay-next"]').trigger("click");
    expect(w.text()).toContain("2対2");
    await w.get('[data-testid="replay-next"]').trigger("click");
    expect(w.text()).toContain("戻してやり直す");
    expect(w.get('[data-testid="replay-play"]').attributes("disabled")).toBeDefined();
    expect(w.get('[data-testid="replay-next"]').attributes("disabled")).toBeDefined();
    await w.get('[data-testid="replay-prev"]').trigger("click");
    expect(w.get('[data-testid="replay-step"]').text()).toContain("4 / 5");
    await w.get('[data-testid="replay-restart"]').trigger("click");
    expect(w.get('[data-testid="replay-step"]').text()).toContain("1 / 5");
  });

  it("再生中に閉じると時計を解除し、再度開くと初期状態になる", async () => {
    const w = await open();
    await w.get('[data-testid="replay-play"]').trigger("click");
    await advance(500);
    await w.get('[data-testid="replay-open"]').trigger("click");
    expect(w.find('[data-testid="replay-step"]').exists()).toBe(false);
    expect(vi.getTimerCount()).toBe(0);
    await w.get('[data-testid="replay-open"]').trigger("click");
    expect(w.get('[data-testid="replay-step"]').text()).toContain("1 / 5");
  });

  it("非表示タブでは一時停止し、unmountで時計を解除する", async () => {
    const w = await open();
    await w.get('[data-testid="replay-play"]').trigger("click");
    vi.spyOn(document, "hidden", "get").mockReturnValue(true);
    document.dispatchEvent(new Event("visibilitychange"));
    await nextTick();
    expect(vi.getTimerCount()).toBe(0);
    vi.restoreAllMocks();
    await w.get('[data-testid="replay-play"]').trigger("click");
    w.unmount();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("動き抑制時は再生操作で次の静止解説へ進み、時計を開始しない", async () => {
    reduced = true;
    const w = await open();
    expect(w.text()).toContain("静止画");
    await w.get('[data-testid="replay-play"]').trigger("click");
    expect(w.get('[data-testid="replay-step"]').text()).toContain("2 / 5");
    expect(vi.getTimerCount()).toBe(0);
  });

  it("再生中に動き抑制へ変更すると次の解説へ到着して停止する", async () => {
    const w = await open();
    await w.get('[data-testid="replay-play"]').trigger("click");
    await advance(500);
    motionChange?.({ matches: true });
    await nextTick();
    expect(w.get('[data-testid="replay-step"]').text()).toContain("2 / 5");
    expect(vi.getTimerCount()).toBe(0);
  });
});
