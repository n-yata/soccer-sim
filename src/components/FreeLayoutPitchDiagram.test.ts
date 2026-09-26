import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import FreeLayoutPitchDiagram from "./FreeLayoutPitchDiagram.vue";
import { getFormationById } from "@/data/formations";
import type { Formation } from "@/types/formation";

// jsdomはSVGGraphicsElement.getScreenCTM/createSVGPointを実装していないため、
// 実際のドラッグ経路（pointerdown→pointermove→座標逆変換→emit）を検証するには
// クライアント座標=SVG内部座標とみなす恒等変換をテスト側で用意する必要がある
// （FreeLayoutPitchDiagram.vue の toPitchCoords が呼ぶAPIをスタブする）。
function stubIdentityCtm(svgElement: SVGSVGElement): void {
  const identityMatrix = {
    inverse: () => identityMatrix,
  } as unknown as DOMMatrix;
  (svgElement as unknown as { getScreenCTM: () => DOMMatrix }).getScreenCTM = () =>
    identityMatrix;
  (svgElement as unknown as { createSVGPoint: () => DOMPoint }).createSVGPoint = () => {
    const point = {
      x: 0,
      y: 0,
      matrixTransform() {
        return { x: point.x, y: point.y };
      },
    };
    return point as unknown as DOMPoint;
  };
}

describe("FreeLayoutPitchDiagram", () => {
  it("formationA/formationBの全選手数分のcircleが、それぞれ青(A)・赤(B)の色で描画される", () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });

    expect(wrapper.findAll("circle.blue")).toHaveLength(formationA.positions.length);
    expect(wrapper.findAll("circle.red")).toHaveLength(formationB.positions.length);
  });

  it("A・B両チームの選手にドラッグ可能クラスが付与される", () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });

    const blueCircles = wrapper.findAll("circle.blue");
    const redCircles = wrapper.findAll("circle.red");
    blueCircles.forEach((circle) => {
      expect(circle.classes()).toContain("free-layout-pitch__player--draggable");
    });
    redCircles.forEach((circle) => {
      expect(circle.classes()).toContain("free-layout-pitch__player--draggable");
    });
  });

  it("Aチームの選手をドラッグすると、team:'A'付きでupdate-positionがemitされる", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const targetPosition = formationA.positions[0];
    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    // 恒等変換なので、渡したclientX/clientYがそのままSVG内部座標(cx/cy)として扱われる。
    // buttons: 1 はボタンを押し続けている状態を表す（0のままだとポインタキャプチャ喪失時の
    // 回復ロジックが働き、ドラッグ終了とみなされてemitされない）
    await wrapper.find("svg").trigger("pointermove", { clientX: 130, clientY: 80, buttons: 1 });

    const emitted = wrapper.emitted("update-position");
    expect(emitted).toHaveLength(1);
    const [team, positionId, x, y] = emitted![0] as [string, string, number, number];
    expect(team).toBe("A");
    expect(positionId).toBe(targetPosition.id);
    // cy=80(高さ中央)→xは50、cx=130(Aチームの深さの最大値=HALF_WIDTH)→yは100(敵陣側)
    expect(x).toBeCloseTo(50);
    expect(y).toBeCloseTo(100);
  });

  it("Bチームの選手をドラッグすると、team:'B'付きでupdate-positionがemitされ、Bチームの深さ変換が使われる", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const targetPosition = formationB.positions[0];
    const redCircle = wrapper.findAll("circle.red")[0];
    await redCircle.trigger("pointerdown", { pointerId: 1 });
    // cx=130(中央)はBチームでも深さ100(敵陣側)相当。Aチームと違い自陣はcx=260側になる
    await wrapper.find("svg").trigger("pointermove", { clientX: 130, clientY: 80, buttons: 1 });

    const emitted = wrapper.emitted("update-position");
    expect(emitted).toHaveLength(1);
    const [team, positionId, x, y] = emitted![0] as [string, string, number, number];
    expect(team).toBe("B");
    expect(positionId).toBe(targetPosition.id);
    expect(x).toBeCloseTo(50);
    expect(y).toBeCloseTo(100);
  });

  it("Aチームのドラッグ中はBチームの位置に影響せず、逆も同様（team別に独立して扱われる）", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    await wrapper.find("svg").trigger("pointermove", { clientX: 130, clientY: 80, buttons: 1 });
    await wrapper.find("svg").trigger("pointerup", { pointerId: 1 });

    const redCircle = wrapper.findAll("circle.red")[0];
    await redCircle.trigger("pointerdown", { pointerId: 2 });
    await wrapper.find("svg").trigger("pointermove", { clientX: 200, clientY: 40, buttons: 1 });

    const emitted = wrapper.emitted("update-position")!;
    expect(emitted).toHaveLength(2);
    expect(emitted[0][0]).toBe("A");
    expect(emitted[1][0]).toBe("B");
  });

  it("ピッチ外の座標へドラッグすると、emitされる値が0-100にクランプされる", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    // cx=-50(ピッチ幅0-260の範囲外)・cy=-20(ピッチ高さ0-160の範囲外)へ移動
    await wrapper.find("svg").trigger("pointermove", { clientX: -50, clientY: -20, buttons: 1 });

    const emitted = wrapper.emitted("update-position");
    expect(emitted).toHaveLength(1);
    const [, , x, y] = emitted![0] as [string, string, number, number];
    expect(x).toBe(0);
    expect(y).toBe(0);
  });

  it("ポインタキャプチャを喪失し(buttons=0)pointermoveが来た場合、emitされずドラッグ状態が終了する", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    // ポインタキャプチャが失われた環境では、ボタンが離されてもこの要素はpointerupを
    // 受け取れないことがある。buttons=0のpointermoveでそれを検知し回復することを検証する
    await wrapper.find("svg").trigger("pointermove", { clientX: 130, clientY: 80, buttons: 0 });
    expect(wrapper.emitted("update-position")).toBeUndefined();

    // 回復後はドラッグ状態が終了しているため、続けてbuttons:1でpointermoveしても
    // （再度pointerdownしない限り）emitされない
    await wrapper.find("svg").trigger("pointermove", { clientX: 100, clientY: 100, buttons: 1 });
    expect(wrapper.emitted("update-position")).toBeUndefined();
  });

  it("CTMが非可逆でNaN座標になった場合、emitされない（NaNを配置状態へ持ち込まない）", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    const svgElement = wrapper.find("svg").element as SVGSVGElement;
    const nanMatrix = { inverse: () => nanMatrix } as unknown as DOMMatrix;
    (svgElement as unknown as { getScreenCTM: () => DOMMatrix }).getScreenCTM = () => nanMatrix;
    (svgElement as unknown as { createSVGPoint: () => DOMPoint }).createSVGPoint = () =>
      ({
        x: 0,
        y: 0,
        matrixTransform: () => ({ x: NaN, y: NaN }),
      }) as unknown as DOMPoint;

    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    await wrapper.find("svg").trigger("pointermove", { clientX: 130, clientY: 80, buttons: 1 });

    expect(wrapper.emitted("update-position")).toBeUndefined();
  });

  it("pointerup後にpointermoveしても、update-positionはemitされない（ドラッグ終了）", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    await wrapper.find("svg").trigger("pointerup", { pointerId: 1 });
    await wrapper.find("svg").trigger("pointermove", { clientX: 130, clientY: 80 });

    expect(wrapper.emitted("update-position")).toBeUndefined();
  });

  it("ドラッグ確定時(pointerup)に、update-position-endが直近の座標で1回だけemitされる", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const targetPosition = formationA.positions[0];
    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    // pointermoveを複数回発生させても、update-positionは複数回emitされるが
    // update-position-endはpointerup時の1回だけになるはず
    await wrapper.find("svg").trigger("pointermove", { clientX: 100, clientY: 60, buttons: 1 });
    await wrapper.find("svg").trigger("pointermove", { clientX: 130, clientY: 80, buttons: 1 });
    expect(wrapper.emitted("update-position")).toHaveLength(2);
    expect(wrapper.emitted("update-position-end")).toBeUndefined();

    await wrapper.find("svg").trigger("pointerup", { pointerId: 1 });

    const endEmitted = wrapper.emitted("update-position-end");
    expect(endEmitted).toHaveLength(1);
    const [team, positionId, x, y] = endEmitted![0] as [string, string, number, number];
    expect(team).toBe("A");
    expect(positionId).toBe(targetPosition.id);
    // 直近(2回目)のpointermoveの座標と一致する
    expect(x).toBeCloseTo(50);
    expect(y).toBeCloseTo(100);
  });

  it("pointermoveが一度も無いままpointerupしても、update-position-endはemitされない", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    await wrapper.find("svg").trigger("pointerup", { pointerId: 1 });

    expect(wrapper.emitted("update-position-end")).toBeUndefined();
  });

  it("ポインタキャプチャ喪失からの回復(pointerup相当)でも、直近の座標でupdate-position-endがemitされる", async () => {
    const formationA = getFormationById("4-3-3") as Formation;
    const formationB = getFormationById("3-5-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });
    stubIdentityCtm(wrapper.find("svg").element as SVGSVGElement);

    const blueCircle = wrapper.findAll("circle.blue")[0];
    await blueCircle.trigger("pointerdown", { pointerId: 1 });
    await wrapper.find("svg").trigger("pointermove", { clientX: 130, clientY: 80, buttons: 1 });
    // buttons=0で回復ロジックが働き、内部的にonPointerUpが呼ばれる
    await wrapper.find("svg").trigger("pointermove", { clientX: 200, clientY: 40, buttons: 0 });

    expect(wrapper.emitted("update-position-end")).toHaveLength(1);
  });

  describe("キーボード操作（WCAG 2.1.1: ポインタ以外での操作手段）", () => {
    it("ラッパーはrole=groupで全体の説明を持ち、選手のcircleはtabindex=0でアクセシブルネームを持つ（role=buttonは付与しない。Enter/Spaceでの活性化を実装していないため、ARIAのbuttonロール契約違反を避ける）", () => {
      const formationA = getFormationById("4-3-3") as Formation;
      const formationB = getFormationById("3-5-2") as Formation;
      const wrapper = mount(FreeLayoutPitchDiagram, {
        props: { formationA, formationB },
      });

      const group = wrapper.find(".free-layout-pitch-wrapper");
      expect(group.attributes("role")).toBe("group");
      expect(group.attributes("aria-label")).toContain(formationA.name);
      expect(group.attributes("aria-label")).toContain(formationB.name);

      const blueCircle = wrapper.findAll("circle.blue")[0];
      expect(blueCircle.attributes("tabindex")).toBe("0");
      expect(blueCircle.attributes("role")).toBeUndefined();
      expect(blueCircle.attributes("aria-label")).toContain("青チーム");

      const redCircle = wrapper.findAll("circle.red")[0];
      expect(redCircle.attributes("tabindex")).toBe("0");
      expect(redCircle.attributes("role")).toBeUndefined();
      expect(redCircle.attributes("aria-label")).toContain("赤チーム");
    });

    it("ピッチの装飾要素（背景・ライン・ペナルティエリア）と選手ラベルのtextは、aria-hidden=trueでスクリーンリーダーの読み上げから除外される（role=groupの子要素として露出するため、装飾まで露出すると雑音になる）", () => {
      const formationA = getFormationById("4-3-3") as Formation;
      const formationB = getFormationById("3-5-2") as Formation;
      const wrapper = mount(FreeLayoutPitchDiagram, {
        props: { formationA, formationB },
      });

      expect(wrapper.find(".free-layout-pitch__field").attributes("aria-hidden")).toBe("true");
      expect(wrapper.find(".free-layout-pitch__outline").attributes("aria-hidden")).toBe("true");
      expect(wrapper.find(".free-layout-pitch__line").attributes("aria-hidden")).toBe("true");
      wrapper.findAll(".free-layout-pitch__label").forEach((label) => {
        expect(label.attributes("aria-hidden")).toBe("true");
      });
    });

    it("矢印キーの押下(keydown)ではupdate-positionのみがemitされ、キーを離す(keyup)まではupdate-position-endはemitされない", async () => {
      const formationA = getFormationById("4-3-3") as Formation;
      const formationB = getFormationById("3-5-2") as Formation;
      const wrapper = mount(FreeLayoutPitchDiagram, {
        props: { formationA, formationB },
      });

      const targetPosition = formationA.positions[0];
      const blueCircle = wrapper.findAll("circle.blue")[0];
      await blueCircle.trigger("keydown", { key: "ArrowRight" });

      expect(wrapper.emitted("update-position")).toHaveLength(1);
      expect(wrapper.emitted("update-position-end")).toBeUndefined();

      await blueCircle.trigger("keyup", { key: "ArrowRight" });

      const endEmitted = wrapper.emitted("update-position-end");
      expect(endEmitted).toHaveLength(1);
      const [team, positionId, x, y] = endEmitted![0] as [string, string, number, number];
      expect(team).toBe("A");
      expect(positionId).toBe(targetPosition.id);
      expect(wrapper.emitted("update-position")![0]).toEqual([team, positionId, x, y]);
    });

    it("キーリピート（keydownの連続発火）が起きても、update-position-endはkeyup時の1回だけemitされる（永続化がキー押下のたびに走らないことの検証）", async () => {
      const formationA = getFormationById("4-3-3") as Formation;
      const formationB = getFormationById("3-5-2") as Formation;
      const wrapper = mount(FreeLayoutPitchDiagram, {
        props: { formationA, formationB },
      });

      const blueCircle = wrapper.findAll("circle.blue")[0];
      // ブラウザのオートリピートを模擬: keyupを伴わない複数回のkeydown
      await blueCircle.trigger("keydown", { key: "ArrowRight" });
      await blueCircle.trigger("keydown", { key: "ArrowRight" });
      await blueCircle.trigger("keydown", { key: "ArrowRight" });
      expect(wrapper.emitted("update-position")).toHaveLength(3);
      expect(wrapper.emitted("update-position-end")).toBeUndefined();

      await blueCircle.trigger("keyup", { key: "ArrowRight" });
      expect(wrapper.emitted("update-position-end")).toHaveLength(1);
    });

    it("矢印キー以外のキーのkeyupではemitされない", async () => {
      const formationA = getFormationById("4-3-3") as Formation;
      const formationB = getFormationById("3-5-2") as Formation;
      const wrapper = mount(FreeLayoutPitchDiagram, {
        props: { formationA, formationB },
      });

      const blueCircle = wrapper.findAll("circle.blue")[0];
      await blueCircle.trigger("keyup", { key: "Enter" });

      expect(wrapper.emitted("update-position-end")).toBeUndefined();
    });

    it("矢印キー以外のキーではemitされない", async () => {
      const formationA = getFormationById("4-3-3") as Formation;
      const formationB = getFormationById("3-5-2") as Formation;
      const wrapper = mount(FreeLayoutPitchDiagram, {
        props: { formationA, formationB },
      });

      const blueCircle = wrapper.findAll("circle.blue")[0];
      await blueCircle.trigger("keydown", { key: "Enter" });

      expect(wrapper.emitted("update-position")).toBeUndefined();
    });

    it("ピッチ範囲外へ移動しようとしても0-100にクランプされる", async () => {
      // y=1（自陣ゴールのすぐ手前）の選手をさらに自陣方向(ArrowLeft)へ押し、
      // 1回の押下で境界を超えても0未満にならないことを検証する
      const nearGoalFormation: Formation = {
        id: "fake",
        name: "fake",
        description: "",
        positions: [{ id: "p1", type: "GK", label: "GK", x: 50, y: 1 }],
        stats: { attack: 50, defense: 50, balance: 50, spaceControl: 50, pressIntensity: 50 },
      };
      const wrapper = mount(FreeLayoutPitchDiagram, {
        props: { formationA: nearGoalFormation, formationB: nearGoalFormation },
      });

      const blueCircle = wrapper.findAll("circle.blue")[0];
      await blueCircle.trigger("keydown", { key: "ArrowLeft" });

      const [, , , y] = wrapper.emitted("update-position")![0] as [string, string, number, number];
      expect(y).toBe(0);
    });
  });

  it("Aチームの選手の座標は実座標(0-100)をfreeLayoutCoordinatesで変換した位置に描画される", () => {
    const formationA = getFormationById("4-4-2") as Formation;
    const formationB = getFormationById("4-4-2") as Formation;
    const wrapper = mount(FreeLayoutPitchDiagram, {
      props: { formationA, formationB },
    });

    const gk = formationA.positions.find((p) => p.type === "GK")!;
    const blueCircles = wrapper.findAll("circle.blue");
    // 4-4-2はGKが最後に描画される（positions配列の並び順どおり）
    const gkCircle = blueCircles[formationA.positions.indexOf(gk)];
    // GK(x=50, y=5)は自陣ゴール付近(cx小さい)・幅方向中央(cy中央付近)になるはず
    expect(Number(gkCircle.attributes("cx"))).toBeLessThan(20);
    expect(Number(gkCircle.attributes("cy"))).toBeCloseTo(80, 0);
  });
});
