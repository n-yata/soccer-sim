import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { reactive } from "vue";
import ComparisonPage from "./ComparisonPage.vue";
import FreeLayoutPitchDiagram from "@/components/FreeLayoutPitchDiagram.vue";
import MatchSimulationPanel from "@/components/MatchSimulationPanel.vue";
import MatchupPitchDiagram from "@/components/MatchupPitchDiagram.vue";
import RadarChart from "@/components/RadarChart.vue";
import { getFormationById } from "@/data/formations";
import { getMatchup } from "@/data/matchups";
import { buildPairKey, loadProgress } from "@/data/learningProgress";
import { simulateMatch } from "@/composables/matchSimulation";

const pushMock = vi.fn();
const replaceMock = vi.fn();
// vue-router の useRoute() は reactive なオブジェクトを返す。plain object のままだと
// route.params を書き換えても ComparisonPage 内の computed / watch が再評価されず、
// A/B切替時の記録を検証できない
const routeState = reactive({
  params: { formationAId: "4-2-3-1", formationBId: "4-4-2" } as {
    formationAId: string;
    formationBId: string;
  },
});

vi.mock("vue-router", () => ({
  useRoute: () => routeState,
  useRouter: () => ({ push: pushMock, replace: replaceMock }),
}));

const routerLinkStub = {
  props: ["to"],
  template: '<a :href="to"><slot /></a>',
};

describe("ComparisonPage", () => {
  beforeEach(() => {
    pushMock.mockClear();
    replaceMock.mockClear();
    routeState.params = { formationAId: "4-2-3-1", formationBId: "4-4-2" };
    window.localStorage.clear();
  });

  it("結論とピッチを表示オプションより先に読み進められる", () => {
    const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
    try {
      const html = wrapper.html();
      expect(wrapper.find(".comparison-page__verdict").exists()).toBe(true);
      expect(wrapper.find(".comparison-page__pitch-overlay").exists()).toBe(true);
      expect(wrapper.find(".comparison-page__options").exists()).toBe(true);
      expect(html.indexOf('class="comparison-page__verdict')).toBeLessThan(
        html.indexOf('class="comparison-page__options'),
      );
      expect(html.indexOf('class="comparison-page__pitch-overlay')).toBeLessThan(
        html.indexOf('class="comparison-page__options'),
      );
    } finally {
      wrapper.unmount();
    }
  });

  // FR-13: 表示できた組み合わせを学習進捗として記録する
  describe("学習進捗の記録", () => {
    // routeStateはreactiveな共有オブジェクトのため、mountしたコンポーネントを
    // unmountしないままにすると、次のテストのbeforeEachでrouteState.paramsを
    // 書き換えた瞬間に「前のテストで残っていたウォッチャー」まで再発火し、
    // localStorageを汚染して他のテストを壊す。ここで確実に片付ける
    let mountedWrappers: ReturnType<typeof mount>[] = [];
    function mountAndTrack() {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      mountedWrappers.push(wrapper);
      return wrapper;
    }

    beforeEach(() => {
      mountedWrappers = [];
    });

    afterEach(() => {
      mountedWrappers.forEach((wrapper) => wrapper.unmount());
    });

    it("マウント時に、表示している組み合わせを確認済みとして記録する", () => {
      mountAndTrack();

      expect(loadProgress().viewedPairs).toContain(buildPairKey("4-2-3-1", "4-4-2"));
    });

    it("A/B入れ替え・切替（同一コンポーネント内のパラメータ変更）でも記録される", async () => {
      const wrapper = mountAndTrack();

      // router.replace 後、実際のアプリでは route.params が更新される。
      // ここでは同一コンポーネント内でのパラメータ変更を、テストからルート状態を
      // 直接書き換えることで再現する
      routeState.params = { formationAId: "3-5-2", formationBId: "4-4-2" };
      await wrapper.vm.$nextTick();

      expect(loadProgress().viewedPairs).toContain(buildPairKey("3-5-2", "4-4-2"));
    });

    it("順序を入れ替えて表示しても、進捗としては同一の組み合わせとして扱われる（二重計上しない）", async () => {
      mountAndTrack();
      expect(loadProgress().viewedPairs).toHaveLength(1);

      routeState.params = { formationAId: "4-4-2", formationBId: "4-2-3-1" };
      const wrapper2 = mountAndTrack();
      await wrapper2.vm.$nextTick();

      expect(loadProgress().viewedPairs).toHaveLength(1);
    });

    it("存在しない組み合わせ（マッチアップ未検出）では記録しない", () => {
      routeState.params = { formationAId: "4-4-2", formationBId: "4-4-2" };
      mountAndTrack();

      expect(loadProgress().viewedPairs).toHaveLength(0);
    });
  });

  it("正しいIDでマウントすると、タイトル・重ね合わせピッチ図・優位ポイントの箇条書きが表示される", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.text()).toContain("4-2-3-1 vs 4-4-2");

    const matchupPitch = wrapper.findComponent(MatchupPitchDiagram);
    expect(matchupPitch.exists()).toBe(true);
    expect(matchupPitch.props("formationA")?.id).toBe("4-2-3-1");
    expect(matchupPitch.props("formationB")?.id).toBe("4-4-2");

    const columns = wrapper.findAll(".comparison-page__advantage-column");
    expect(columns).toHaveLength(2);
    columns.forEach((column) => {
      expect(column.findAll("li").length).toBeGreaterThan(0);
    });

    // このケースはルートパラメータが data/matchups.ts のレコード格納順序（"4-4-2"→"4-2-3-1"）
    // と逆（"4-2-3-1"→"4-4-2"）なので、getMatchup の正規化ロジック（入れ替え）を通る。
    // 青カラム（formationA="4-2-3-1"側）に4-2-3-1の優位ポイントが、赤カラム
    // （formationB="4-4-2"側）に4-4-2の優位ポイントが表示されることを直接検証する
    // （取り違えて逆に表示されてもテストが緑になる恒真テストを避けるため）。
    expect(columns[0].text()).toContain(
      "守備的MF2枚が相手の2トップに数的同数でマンツーマン気味に対応でき",
    );
    expect(columns[1].text()).toContain(
      "2トップが相手の守備的MF2枚の脇や背後のスペースを突きやすい",
    );

    // 総合判定（どちらが有利か）が表示される。この組み合わせは overallEdge が
    // 入れ替えにより "B"→"A" に反転し、formationA（4-2-3-1）がやや優位と表示される
    const verdict = wrapper.find(".comparison-page__verdict");
    expect(verdict.text()).toContain("4-2-3-1がやや優位");
  });

  it("RadarChartにformationA/Bのstatsがそれぞれ正しく渡る", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const radarChart = wrapper.findComponent(RadarChart);
    expect(radarChart.exists()).toBe(true);

    const formationA = getFormationById("4-2-3-1");
    const formationB = getFormationById("4-4-2");
    const series = radarChart.props("series") as {
      label: string;
      colorVar: string;
      values: unknown;
    }[];
    expect(series).toHaveLength(2);
    expect(series[0]).toEqual({
      label: "4-2-3-1",
      colorVar: "--color-team-a",
      values: formationA?.stats,
    });
    expect(series[1]).toEqual({
      label: "4-4-2",
      colorVar: "--color-team-b",
      values: formationB?.stats,
    });
  });

  it("overallEdgeがevenの組み合わせでは、総合判定に「互角」と表示される", () => {
    routeState.params = { formationAId: "4-4-2", formationBId: "4-3-3" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const verdict = wrapper.find(".comparison-page__verdict");
    expect(verdict.text()).toContain("互角");
  });

  it("formationAIdが存在しない場合、エラーメッセージが表示されピッチ図は描画されない", () => {
    routeState.params = { formationAId: "存在しないID", formationBId: "4-4-2" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.text()).toContain("表示できません");
    expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(false);
  });

  it("formationBIdが存在しない場合も同様にエラーメッセージが表示される", () => {
    routeState.params = { formationAId: "4-2-3-1", formationBId: "存在しないID" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.text()).toContain("表示できません");
    expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(false);
  });

  it("同一フォーメーション同士のIDでアクセスした場合、エラーメッセージが表示されピッチ図は描画されない", () => {
    // 一覧画面はトグル方式のため通常発生しないが、URL直打ちで到達しうる状態
    // （getFormationByIdは両方成功するがgetMatchupがundefinedになるケース）。
    routeState.params = { formationAId: "4-4-2", formationBId: "4-4-2" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    expect(wrapper.text()).toContain("表示できません");
    expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(false);
  });

  it("「← 戻る」をクリックするとrouter.pushが'/'で1回呼ばれる", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    await wrapper.find("button").trigger("click");
    expect(pushMock).toHaveBeenCalledTimes(1);
    expect(pushMock).toHaveBeenCalledWith("/");
  });

  it("エラー時に表示される一覧画面へのリンクが'/'を指す", () => {
    routeState.params = { formationAId: "存在しないID", formationBId: "4-4-2" };
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const link = wrapper.find("a");
    expect(link.attributes("href")).toBe("/");
  });

  it("comparison-page__mainがflex-wrap:wrapで、狭い画面でピッチ図とレーダーチャートが横並びから縦積みへ切り替わる", () => {
    const wrapper = mount(ComparisonPage, {
      attachTo: document.body,
      global: { stubs: { RouterLink: routerLinkStub } },
    });

    const main = wrapper.find(".comparison-page__main");
    const mainStyle = getComputedStyle(main.element);
    expect(mainStyle.display).toBe("flex");
    // flex-wrap:wrap が外れると、画面が狭くてもピッチ図とレーダーチャートが
    // 常に横並びのままレイアウトが崩れる（縦積みへの切り替えができなくなる）
    expect(mainStyle.flexWrap).toBe("wrap");

    // 各カラムがflex-basisを持つことで、コンテナ幅がbasis合計を下回った際に
    // wrapが発動する。0や未設定に戻すとwrapが機能しなくなるため固定しておく。
    const pitchOverlay = wrapper.find(".comparison-page__pitch-overlay");
    const radar = wrapper.find(".comparison-page__radar");
    expect(getComputedStyle(pitchOverlay.element).flexBasis).toBe("520px");
    expect(getComputedStyle(radar.element).flexBasis).toBe("320px");

    wrapper.unmount();
  });

  it("comparison-page__bodyがページ全体の上限幅を持ち、広い画面幅で中央寄せされる", () => {
    const wrapper = mount(ComparisonPage, {
      attachTo: document.body,
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const body = wrapper.find(".comparison-page__body");
    const bodyStyle = getComputedStyle(body.element);
    // jsdomはCSSカスタムプロパティを解決しないため、期待値は「正しいトークン参照を
    // 使っているか」で検証する（design.md「jsdomのCSS変数非解決によるテスト期待値の更新」参照）
    // UI/UXモダナイゼーションPhase3（コンテナ幅の全画面統一）により、
    // 画面ごとに異なるトークン(--width-full)ではなく他画面と同じ--width-wideへ変更
    expect(bodyStyle.maxWidth).toBe("var(--width-wide)");
    expect(bodyStyle.marginLeft).toBe("auto");
    expect(bodyStyle.marginRight).toBe("auto");
    wrapper.unmount();
  });

  it("「⇄ 入れ替え」をクリックすると、A/Bが逆順のURLでrouter.replaceが呼ばれる", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    await wrapper.find(".comparison-controls__swap-button").trigger("click");
    expect(replaceMock).toHaveBeenCalledTimes(1);
    expect(replaceMock).toHaveBeenCalledWith("/compare/4-4-2/4-2-3-1");
    expect(pushMock).not.toHaveBeenCalled();
  });

  it("青チーム側のセレクトを変更すると、新しい組み合わせでrouter.replaceが呼ばれる", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const select = wrapper.find("#comparison-select-a");
    await select.setValue("3-5-2");
    expect(replaceMock).toHaveBeenCalledTimes(1);
    expect(replaceMock).toHaveBeenCalledWith("/compare/3-5-2/4-4-2");
    expect(pushMock).not.toHaveBeenCalled();
  });

  it("赤チーム側のセレクトを変更すると、新しい組み合わせでrouter.replaceが呼ばれる", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const select = wrapper.find("#comparison-select-b");
    await select.setValue("3-5-2");
    expect(replaceMock).toHaveBeenCalledTimes(1);
    expect(replaceMock).toHaveBeenCalledWith("/compare/4-2-3-1/3-5-2");
    expect(pushMock).not.toHaveBeenCalled();
  });

  // FR-11: 解説文中の用語をその場で引ける
  it("優位ポイント中のサッカー用語が、説明を開けるボタンとして表示される", async () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });

    const columns = wrapper.findAll(".comparison-page__advantage-column");
    // 青カラムの「守備的MF2枚が相手の2トップに数的同数でマンツーマン気味に…」に含まれる用語
    const termButton = columns[0]
      .findAll("button.term-annotated-text__term")
      .find((b) => b.text() === "マンツーマン");
    expect(termButton).toBeDefined();

    await termButton!.trigger("click");

    const tooltip = columns[0].find('[role="tooltip"]');
    expect(tooltip.exists()).toBe(true);
    expect(tooltip.text()).toContain("相手の特定の1人にほぼ付きっきりで対応する守り方");
  });

  it("総合判定理由の中の用語にも説明を開けるボタンが付く", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });

    // overallReason は「4-2-3-1は中盤が実質5枚と4-4-2の4枚を上回り、中盤の主導権を握りやすい」
    const reason = wrapper.find(".comparison-page__verdict-reason");
    const labels = reason.findAll("button.term-annotated-text__term").map((b) => b.text());
    expect(labels).toContain("中盤");
  });

  it("用語を注釈しても、優位ポイントの本文が欠落しない", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });

    // 用語ボタンへの切り出しで文字が落ちたり重複したりしないことを本文全体で確認する
    const columns = wrapper.findAll(".comparison-page__advantage-column");
    expect(columns[0].text().replace(/\s/g, "")).toContain(
      "守備的MF2枚が相手の2トップに数的同数でマンツーマン気味に対応でき、数的な破綻を防ぎやすい",
    );
  });

  // FR-14: 試合シミュレーション
  describe("試合シミュレーション", () => {
    it("初期表示ではシミュレーション結果パネルを表示しない", () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(false);
    });

    it("ボタンを押すとシミュレーション結果パネルが表示され、フォーメーション名が渡される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");

      const panel = wrapper.findComponent(MatchSimulationPanel);
      expect(panel.exists()).toBe(true);
      expect(panel.props("formationAName")).toBe("4-2-3-1");
      expect(panel.props("formationBName")).toBe("4-4-2");
      expect(panel.props("result")).toBeTruthy();
    });

    it("結果表示後はボタンが消える（再実行しても同じ結果にしかならないため、再クリックの導線を持たない）", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      expect(wrapper.find(".comparison-page__simulate-button").exists()).toBe(true);

      await wrapper.find(".comparison-page__simulate-button").trigger("click");

      expect(wrapper.find(".comparison-page__simulate-button").exists()).toBe(false);
      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(true);
    });

    it("フォーメーションの組み合わせが変わると、表示中のシミュレーション結果がリセットされる", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(true);

      routeState.params = { formationAId: "3-5-2", formationBId: "4-4-2" };
      await wrapper.vm.$nextTick();

      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(false);
      expect(wrapper.find(".comparison-page__simulate-button").exists()).toBe(true);
    });
  });

  // ハーフタイム采配（.steering/20260919-halftime-tactics）
  describe("ハーフタイム采配", () => {
    it("シミュレーション実行直後は前半の部分結果のみが表示され、まだ最終結果ではない", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");

      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(true);
      expect(wrapper.find(".comparison-page__halftime-tactics-button").exists()).toBe(true);
      expect(wrapper.find(".comparison-page__halftime-continue-button").exists()).toBe(true);
      // 前半の部分結果であることの直接的な証拠（buildHalftimeSummaryの文言）
      expect(wrapper.findComponent(MatchSimulationPanel).props("result").summary).toContain(
        "前半終了",
      );
    });

    it("配置を変更せず「後半を開始する」を押すと、simulateMatchの90分通し結果と完全に一致する最終結果になる", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      await wrapper.find(".comparison-page__halftime-continue-button").trigger("click");

      expect(wrapper.find(".comparison-page__halftime-tactics-button").exists()).toBe(false);
      const panel = wrapper.findComponent(MatchSimulationPanel);
      expect(panel.exists()).toBe(true);

      const formationA = getFormationById("4-2-3-1")!;
      const formationB = getFormationById("4-4-2")!;
      const matchup = getMatchup(formationA.id, formationB.id)!;
      const expected = simulateMatch(formationA, formationB, matchup);
      expect(panel.props("result")).toEqual(expected);
    });

    it("「配置を変更する」でモーダルが開き、A/B双方の配置変更を確定すると、後半の結果に反映され、モーダルは閉じる", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      await wrapper.find(".comparison-page__halftime-tactics-button").trigger("click");

      expect(wrapper.find(".halftime-modal-backdrop").exists()).toBe(true);

      const modalDiagram = wrapper.find(".halftime-modal").findComponent(FreeLayoutPitchDiagram);
      expect(modalDiagram.exists()).toBe(true);

      const formationA = getFormationById("4-2-3-1")!;
      const formationB = getFormationById("4-4-2")!;
      const dm1 = formationA.positions.find((p) => p.id === "4-2-3-1-dm1")!;
      const dfPosition = formationB.positions.find((p) => p.type === "DF")!;
      modalDiagram.vm.$emit("update-position", "A", dm1.id, dm1.x, 65);
      modalDiagram.vm.$emit("update-position", "B", dfPosition.id, dfPosition.x, 30);
      await wrapper.find(".halftime-modal__confirm").trigger("click");

      expect(wrapper.find(".halftime-modal-backdrop").exists()).toBe(false);
      expect(wrapper.find(".comparison-page__halftime-tactics-button").exists()).toBe(false);
      const panel = wrapper.findComponent(MatchSimulationPanel);
      expect(panel.exists()).toBe(true);

      // 配置変更後は静的なsimulateMatch(未変更)の結果とは一致しない可能性が高いことを
      // 確認する（完全な不一致の保証はできないが、通常は異なる結果になる）
      const matchup = getMatchup(formationA.id, formationB.id)!;
      const unchanged = simulateMatch(formationA, formationB, matchup);
      expect(panel.props("result")).not.toEqual(unchanged);
    });

    it("Escapeキーでモーダルを閉じても後半は開始されず、ハーフタイムパネルに留まる", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      await wrapper.find(".comparison-page__halftime-tactics-button").trigger("click");
      expect(wrapper.find(".halftime-modal-backdrop").exists()).toBe(true);

      document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
      await wrapper.vm.$nextTick();

      expect(wrapper.find(".halftime-modal-backdrop").exists()).toBe(false);
      expect(wrapper.find(".comparison-page__halftime-tactics-button").exists()).toBe(true);
      expect(wrapper.findComponent(MatchSimulationPanel).props("result").summary).toContain(
        "前半終了",
      );
    });

    it("ハーフタイム状態で組み合わせが変わると、ハーフタイムパネル・モーダルもリセットされる", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      await wrapper.find(".comparison-page__halftime-tactics-button").trigger("click");
      expect(wrapper.find(".halftime-modal-backdrop").exists()).toBe(true);

      routeState.params = { formationAId: "3-5-2", formationBId: "4-4-2" };
      await wrapper.vm.$nextTick();

      expect(wrapper.find(".halftime-modal-backdrop").exists()).toBe(false);
      expect(wrapper.find(".comparison-page__halftime-tactics-button").exists()).toBe(false);
      expect(wrapper.find(".comparison-page__simulate-button").exists()).toBe(true);
    });
  });

  // 自由配置モード（.steering/20260918-自由配置モード）
  describe("自由配置モード", () => {
    function findToggle(wrapper: ReturnType<typeof mount>) {
      return wrapper.find(".free-layout-controls__toggle");
    }

    it("初期表示では自由配置モードはOFFで、通常のMatchupPitchDiagramが表示される", () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(true);
      expect(wrapper.findComponent(FreeLayoutPitchDiagram).exists()).toBe(false);
    });

    it("トグルをONにすると、FreeLayoutPitchDiagramに切り替わりAチームの配置が渡される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");

      expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(false);
      const freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      expect(freeLayout.exists()).toBe(true);
      const formationA = getFormationById("4-2-3-1");
      expect(freeLayout.props("formationA")?.positions).toEqual(formationA?.positions);
      expect(freeLayout.props("formationB")?.id).toBe("4-4-2");
    });

    it("配置変更(update-position)で、優位ポイント・総合判定・レーダーチャートのAチーム側が再計算される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");

      // トグルON直後（座標未変更）の時点の値を先に取っておく。
      // estimateStatsはトグルON時点で既にbaseStatsと同値の新オブジェクトを返すため、
      // 「formationA.statsと参照が異なるか」だけを見ると常に真になり恒真テストになる
      // （タグ構成が変わっていなくても検出できない）。ここでは「emit前後で値そのものが
      // 変わるか」を比較することで、update-positionが実際にfreePositionsAへ反映され、
      // タグ再導出→matchup/estimateStatsの再計算まで駆動されていることを検証する
      const radarChartBefore = wrapper.findComponent(RadarChart);
      const statsBefore = (
        radarChartBefore.props("series") as { values: Record<string, number> }[]
      )[0].values;
      const advantagesBefore = wrapper
        .findAll(".comparison-page__advantage-column--blue li")
        .map((li) => li.text());
      expect(advantagesBefore.some((text) => text.includes("マンツーマン気味に対応でき"))).toBe(
        true,
      );

      // 4-2-3-1のDM(id: 4-2-3-1-dm1, y=40)を攻撃的MFの高さ(y=65)まで押し上げる。
      // deriveTagsはMFの人数ではなくy座標のしきい値で「守備的MF2枚」/「アンカー1枚」を
      // 判定するため（formationTags.ts）、この移動で守備的MFが2人→1人になり
      // 「守備的MF2枚」が消えて「アンカー1枚」が立つ（タグ構成が実際に変わる）
      const formationA = getFormationById("4-2-3-1")!;
      const dm1 = formationA.positions.find((p) => p.id === "4-2-3-1-dm1")!;
      const freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      freeLayout.vm.$emit("update-position", "A", dm1.id, dm1.x, 65);
      await wrapper.vm.$nextTick();

      // 総合判定・優位ポイント: 「守備的MF2枚」に依存する優位ポイントの文言が消える
      // （matchupRules.tsの該当ルールはselfTags:["守備的MF2枚"]を要求するため）
      const advantagesAfter = wrapper
        .findAll(".comparison-page__advantage-column--blue li")
        .map((li) => li.text());
      expect(advantagesAfter.some((text) => text.includes("マンツーマン気味に対応でき"))).toBe(
        false,
      );

      // レーダーチャート: 守備的MF2枚(defense+5/pressIntensity+5)が消え、
      // アンカー1枚(defense-5/balance-5)が立つ差分が、baseStatsに対して適用される
      const radarChartAfter = wrapper.findComponent(RadarChart);
      const statsAfter = (
        radarChartAfter.props("series") as { values: Record<string, number> }[]
      )[0].values;
      expect(statsAfter).not.toEqual(statsBefore);
      expect(statsAfter.defense).toBe(statsBefore.defense - 10);
      expect(statsAfter.balance).toBe(statsBefore.balance - 5);
      expect(statsAfter.pressIntensity).toBe(statsBefore.pressIntensity - 5);
    });

    it("トグルをOFFにすると、元の配置・通常表示に戻る", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");
      await findToggle(wrapper).trigger("click");

      expect(wrapper.findComponent(FreeLayoutPitchDiagram).exists()).toBe(false);
      expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(true);
    });

    it("組み合わせを切り替えると、自由配置モードがOFFに戻る", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");
      expect(wrapper.findComponent(FreeLayoutPitchDiagram).exists()).toBe(true);

      routeState.params = { formationAId: "3-5-2", formationBId: "4-4-2" };
      await wrapper.vm.$nextTick();

      expect(wrapper.findComponent(FreeLayoutPitchDiagram).exists()).toBe(false);
      expect(wrapper.findComponent(MatchupPitchDiagram).exists()).toBe(true);
    });

    it("リセットボタンで、変更した配置が元のフォーメーション定義に戻る", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");

      const formationA = getFormationById("4-2-3-1")!;
      const dfPosition = formationA.positions.find((p) => p.type === "DF")!;
      let freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      freeLayout.vm.$emit("update-position", "A", dfPosition.id, 50, 90);
      await wrapper.vm.$nextTick();

      await wrapper.find(".free-layout-controls__reset").trigger("click");

      freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      expect(freeLayout.props("formationA")?.positions).toEqual(formationA.positions);
      // リセット後もモード自体はONのまま
      expect(freeLayout.exists()).toBe(true);
    });

    it("自由配置トグルON時、表示中の試合シミュレーション結果が破棄される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(true);

      await findToggle(wrapper).trigger("click");

      // トグルON後の配置に基づかない古いシミュレーション結果を残さない
      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(false);
      expect(wrapper.find(".comparison-page__simulate-button").exists()).toBe(true);
    });

    it("配置変更(update-position)で、表示中の試合シミュレーション結果が破棄される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(true);

      const formationA = getFormationById("4-2-3-1")!;
      const dm1 = formationA.positions.find((p) => p.id === "4-2-3-1-dm1")!;
      const freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      freeLayout.vm.$emit("update-position", "A", dm1.id, dm1.x, 65);
      await wrapper.vm.$nextTick();

      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(false);
      expect(wrapper.find(".comparison-page__simulate-button").exists()).toBe(true);
    });

    // Bチームの自由配置・永続化（.steering/20260926-free-layout-b-and-persistence）
    it("Bチームの選手をドラッグすると、Bチームの配置が反映され、レーダーチャートのBチーム側が再計算される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");

      const radarChartBefore = wrapper.findComponent(RadarChart);
      const statsBefore = (
        radarChartBefore.props("series") as { values: Record<string, number> }[]
      )[1].values;

      const formationB = getFormationById("4-4-2")!;
      const cm1 = formationB.positions.find((p) => p.id === "4-4-2-cm1")!;
      let freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      // 中盤4枚のy分布を崩し、フラット→ダイヤへタグが変わるよう大きく動かす
      // （formationTags.tsのFLAT_MIDFIELD_Y_SPREAD判定を踏まえた移動量）
      freeLayout.vm.$emit("update-position", "B", cm1.id, cm1.x, 90);
      await wrapper.vm.$nextTick();

      freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      expect(
        freeLayout.props("formationB")?.positions.find((p: { id: string }) => p.id === cm1.id),
      ).toMatchObject({ x: cm1.x, y: 90 });

      const radarChartAfter = wrapper.findComponent(RadarChart);
      const statsAfter = (
        radarChartAfter.props("series") as { values: Record<string, number> }[]
      )[1].values;
      expect(statsAfter).not.toEqual(statsBefore);
    });

    it("Aチームの配置変更はBチームの表示に影響せず、逆も同様（A/Bは独立して扱われる）", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");

      const formationB = getFormationById("4-4-2")!;
      const freeLayoutBefore = wrapper.findComponent(FreeLayoutPitchDiagram);
      const bPositionsBefore = freeLayoutBefore.props("formationB")?.positions;

      const formationA = getFormationById("4-2-3-1")!;
      const dm1 = formationA.positions.find((p) => p.id === "4-2-3-1-dm1")!;
      freeLayoutBefore.vm.$emit("update-position", "A", dm1.id, dm1.x, 65);
      await wrapper.vm.$nextTick();

      const freeLayoutAfter = wrapper.findComponent(FreeLayoutPitchDiagram);
      expect(freeLayoutAfter.props("formationB")?.positions).toEqual(bPositionsBefore);
      expect(freeLayoutAfter.props("formationB")?.positions).toEqual(formationB.positions);
    });

    it("リセットボタンで、A・B両チームの配置が元のフォーメーション定義に戻る", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");

      const formationA = getFormationById("4-2-3-1")!;
      const formationB = getFormationById("4-4-2")!;
      const dfPosition = formationA.positions.find((p) => p.type === "DF")!;
      const cm1 = formationB.positions.find((p) => p.id === "4-4-2-cm1")!;
      let freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      freeLayout.vm.$emit("update-position", "A", dfPosition.id, 50, 90);
      freeLayout.vm.$emit("update-position", "B", cm1.id, cm1.x, 90);
      await wrapper.vm.$nextTick();

      await wrapper.find(".free-layout-controls__reset").trigger("click");

      freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
      expect(freeLayout.props("formationA")?.positions).toEqual(formationA.positions);
      expect(freeLayout.props("formationB")?.positions).toEqual(formationB.positions);
    });

    describe("自由配置の永続化", () => {
      it("配置変更後、トグルをOFF→ONにすると、直前にドラッグした配置が復元される", async () => {
        const wrapper = mount(ComparisonPage, {
          global: { stubs: { RouterLink: routerLinkStub } },
        });
        await findToggle(wrapper).trigger("click");

        const formationA = getFormationById("4-2-3-1")!;
        const dfPosition = formationA.positions.find((p) => p.type === "DF")!;
        let freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
        freeLayout.vm.$emit("update-position", "A", dfPosition.id, 42, 77);
        // 永続化はドラッグ確定時（update-position-end）にのみ行われる
        freeLayout.vm.$emit("update-position-end", "A", dfPosition.id, 42, 77);
        await wrapper.vm.$nextTick();

        await findToggle(wrapper).trigger("click"); // OFF
        await findToggle(wrapper).trigger("click"); // ON

        freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
        const restored = freeLayout
          .props("formationA")
          ?.positions.find((p: { id: string }) => p.id === dfPosition.id);
        expect(restored).toMatchObject({ x: 42, y: 77 });
      });

      it("ページ再読み込み相当（コンポーネント再マウント）後も、保存済みの配置が復元される", async () => {
        const wrapper = mount(ComparisonPage, {
          global: { stubs: { RouterLink: routerLinkStub } },
        });
        await findToggle(wrapper).trigger("click");

        const formationA = getFormationById("4-2-3-1")!;
        const dfPosition = formationA.positions.find((p) => p.type === "DF")!;
        const freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
        freeLayout.vm.$emit("update-position", "A", dfPosition.id, 33, 88);
        freeLayout.vm.$emit("update-position-end", "A", dfPosition.id, 33, 88);
        await wrapper.vm.$nextTick();
        wrapper.unmount();

        // 再マウント = リロード後の再訪問を模擬（localStorageは維持されたまま）
        const remounted = mount(ComparisonPage, {
          global: { stubs: { RouterLink: routerLinkStub } },
        });
        await findToggle(remounted).trigger("click");

        const restoredLayout = remounted.findComponent(FreeLayoutPitchDiagram);
        const restored = restoredLayout
          .props("formationA")
          ?.positions.find((p: { id: string }) => p.id === dfPosition.id);
        expect(restored).toMatchObject({ x: 33, y: 88 });
        remounted.unmount();
      });

      it("同じフォーメーションを別の組み合わせで表示しても、保存済みの配置が復元される", async () => {
        const wrapper = mount(ComparisonPage, {
          global: { stubs: { RouterLink: routerLinkStub } },
        });
        await findToggle(wrapper).trigger("click");

        const formationA = getFormationById("4-2-3-1")!;
        const dfPosition = formationA.positions.find((p) => p.type === "DF")!;
        const freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
        freeLayout.vm.$emit("update-position", "A", dfPosition.id, 25, 66);
        freeLayout.vm.$emit("update-position-end", "A", dfPosition.id, 25, 66);
        await wrapper.vm.$nextTick();

        // 同じフォーメーション(4-2-3-1)を別の相手(3-5-2)との組み合わせで表示する
        routeState.params = { formationAId: "4-2-3-1", formationBId: "3-5-2" };
        await wrapper.vm.$nextTick();
        await findToggle(wrapper).trigger("click");

        const restoredLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
        const restored = restoredLayout
          .props("formationA")
          ?.positions.find((p: { id: string }) => p.id === dfPosition.id);
        expect(restored).toMatchObject({ x: 25, y: 66 });
      });

      it("リセット操作後は保存データも削除され、再度ONにしても元の配置から始まる", async () => {
        const wrapper = mount(ComparisonPage, {
          global: { stubs: { RouterLink: routerLinkStub } },
        });
        await findToggle(wrapper).trigger("click");

        const formationA = getFormationById("4-2-3-1")!;
        const dfPosition = formationA.positions.find((p) => p.type === "DF")!;
        let freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
        freeLayout.vm.$emit("update-position", "A", dfPosition.id, 25, 66);
        freeLayout.vm.$emit("update-position-end", "A", dfPosition.id, 25, 66);
        await wrapper.vm.$nextTick();

        await wrapper.find(".free-layout-controls__reset").trigger("click");
        await findToggle(wrapper).trigger("click"); // OFF
        await findToggle(wrapper).trigger("click"); // ON

        freeLayout = wrapper.findComponent(FreeLayoutPitchDiagram);
        expect(freeLayout.props("formationA")?.positions).toEqual(formationA.positions);
      });
    });
  });

  // 選手個体差（スカッドコンディション。.steering/20260920-cup-and-player-variance）
  describe("選手個体差", () => {
    function findToggle(wrapper: ReturnType<typeof mount>) {
      return wrapper.find(".squad-condition-controls__toggle");
    }

    it("初期表示では選手個体差はOFFで、リロールボタンは表示されない", () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      expect(findToggle(wrapper).attributes("aria-pressed")).toBe("false");
      expect(wrapper.find(".squad-condition-controls__reroll").exists()).toBe(false);
    });

    it("トグルをONにすると、リロールボタンが表示される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");
      expect(findToggle(wrapper).attributes("aria-pressed")).toBe("true");
      expect(wrapper.find(".squad-condition-controls__reroll").exists()).toBe(true);
    });

    it("OFFのままシミュレーションしても、レーダーチャートのAチーム側stats(formationA.stats)は変化しない", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      const formationA = getFormationById("4-2-3-1");
      await wrapper.find(".comparison-page__simulate-button").trigger("click");

      const radarChart = wrapper.findComponent(RadarChart);
      const statsA = (radarChart.props("series") as { values: unknown }[])[0].values;
      expect(statsA).toEqual(formationA?.stats);
    });

    it("ONにしても、レーダーチャートのAチーム側stats(formationA.stats)は変化しない（影響範囲が試合シミュレーションのみのため）", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      const formationA = getFormationById("4-2-3-1");
      await findToggle(wrapper).trigger("click");

      const radarChart = wrapper.findComponent(RadarChart);
      const statsA = (radarChart.props("series") as { values: unknown }[])[0].values;
      expect(statsA).toEqual(formationA?.stats);
    });

    it("トグルON時、表示中の試合シミュレーション結果が破棄される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(true);

      await findToggle(wrapper).trigger("click");

      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(false);
      expect(wrapper.find(".comparison-page__simulate-button").exists()).toBe(true);
    });

    it("リロール時、表示中の試合シミュレーション結果が破棄される", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");
      await wrapper.find(".comparison-page__simulate-button").trigger("click");
      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(true);

      await wrapper.find(".squad-condition-controls__reroll").trigger("click");

      expect(wrapper.findComponent(MatchSimulationPanel).exists()).toBe(false);
      expect(wrapper.find(".comparison-page__simulate-button").exists()).toBe(true);
    });

    it("組み合わせを切り替えると、選手個体差がOFFに戻る", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");
      expect(findToggle(wrapper).attributes("aria-pressed")).toBe("true");

      routeState.params = { formationAId: "3-5-2", formationBId: "4-4-2" };
      await wrapper.vm.$nextTick();

      expect(findToggle(wrapper).attributes("aria-pressed")).toBe("false");
      expect(wrapper.find(".squad-condition-controls__reroll").exists()).toBe(false);
    });

    it("トグルをOFFに戻すと、リロールボタンが消える", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await findToggle(wrapper).trigger("click");
      await findToggle(wrapper).trigger("click");

      expect(findToggle(wrapper).attributes("aria-pressed")).toBe("false");
      expect(wrapper.find(".squad-condition-controls__reroll").exists()).toBe(false);
    });
  });

  // 表示オプションパネル（自由配置・選手個体差のグルーピング。2026-09-28）
  describe("表示オプションパネル", () => {
    function panel(wrapper: ReturnType<typeof mount>) {
      return wrapper.find(".comparison-page__options");
    }

    function isOpen(wrapper: ReturnType<typeof mount>): boolean {
      return (panel(wrapper).element as HTMLDetailsElement).open;
    }

    it("初期表示では閉じている", () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      expect(isOpen(wrapper)).toBe(false);
    });

    it("自由配置モードをONにすると、パネルが自動的に開く", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".free-layout-controls__toggle").trigger("click");
      expect(isOpen(wrapper)).toBe(true);
    });

    it("選手個体差をONにすると、パネルが自動的に開く", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".squad-condition-controls__toggle").trigger("click");
      expect(isOpen(wrapper)).toBe(true);
    });

    // detailsのopenをVueの式へ直結すると、ユーザーがクリックして開閉した直後に
    // 式の再評価でDOMが上書きされ、パネルが勝手に閉じてしまう回帰を防ぐ
    it("手動で開いたあと機能をON→OFFしても、パネルは開いたままになる", async () => {
      const wrapper = mount(ComparisonPage, { global: { stubs: { RouterLink: routerLinkStub } } });
      await wrapper.find(".comparison-page__options-summary").trigger("click");
      expect(isOpen(wrapper)).toBe(true);

      await wrapper.find(".free-layout-controls__toggle").trigger("click"); // ON
      await wrapper.find(".free-layout-controls__toggle").trigger("click"); // OFF

      expect(isOpen(wrapper)).toBe(true);
    });
  });

  it("各セレクトで、相手側に選択済みのフォーメーションがdisabledになっている", () => {
    const wrapper = mount(ComparisonPage, {
      global: { stubs: { RouterLink: routerLinkStub } },
    });
    const optionsA = wrapper.find("#comparison-select-a").findAll("option");
    const disabledInA = optionsA.find((option) => option.attributes("value") === "4-4-2");
    expect(disabledInA?.attributes("disabled")).toBeDefined();

    const optionsB = wrapper.find("#comparison-select-b").findAll("option");
    const disabledInB = optionsB.find((option) => option.attributes("value") === "4-2-3-1");
    expect(disabledInB?.attributes("disabled")).toBeDefined();
  });
});
