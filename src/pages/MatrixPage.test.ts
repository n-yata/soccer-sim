import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import type { Formation } from "@/types/formation";

const pushMock = vi.fn();
vi.mock("vue-router", () => ({
  useRouter: () => ({ push: pushMock }),
}));

const state = vi.hoisted(() => ({
  formations: [] as Formation[],
  // 指定した組み合わせに対してのみgetMatchupをundefined化する（異常系テスト用）
  forceUndefinedFor: null as null | { rowId: string; colId: string },
}));

vi.mock("@/data/formations", () => ({
  get formations() {
    return state.formations;
  },
}));

vi.mock("@/data/matchups", async () => {
  const actual =
    await vi.importActual<typeof import("@/data/matchups")>("@/data/matchups");
  return {
    getMatchup: (formationAId: string, formationBId: string) => {
      const forced = state.forceUndefinedFor;
      const isForced =
        forced !== null &&
        ((forced.rowId === formationAId && forced.colId === formationBId) ||
          (forced.rowId === formationBId && forced.colId === formationAId));
      if (isForced) return undefined;
      return actual.getMatchup(formationAId, formationBId);
    },
  };
});

const { formations: realFormations } =
  await vi.importActual<typeof import("@/data/formations")>("@/data/formations");

const { default: MatrixPage } = await import("./MatrixPage.vue");

const routerLinkStub = {
  props: ["to"],
  template: '<a :href="to"><slot /></a>',
};

function mountMatrix() {
  return mount(MatrixPage, {
    global: { stubs: { RouterLink: routerLinkStub } },
  });
}

describe("MatrixPage", () => {
  beforeEach(() => {
    pushMock.mockClear();
    state.formations = realFormations;
    state.forceUndefinedFor = null;
  });

  it("フォーメーション件数×件数のセル（<td>）が描画される", () => {
    const wrapper = mountMatrix();
    const cells = wrapper.findAll("tbody td");
    expect(cells).toHaveLength(realFormations.length * realFormations.length);
  });

  it("見出し行・見出し列に全フォーメーション名が表示される", () => {
    const wrapper = mountMatrix();
    const colHeaders = wrapper.findAll("thead th");
    // 先頭の空セル(行見出し用の空th)を除いた列数がフォーメーション数と一致する
    expect(colHeaders).toHaveLength(realFormations.length + 1);
    realFormations.forEach((formation) => {
      expect(wrapper.text()).toContain(formation.name);
    });
  });

  it("対角線セル（同一フォーメーション同士）はリンクではなく、クリックできない", () => {
    const wrapper = mountMatrix();
    const rows = wrapper.findAll("tbody tr");
    rows.forEach((row, index) => {
      const cells = row.findAll("td");
      const diagonalCell = cells[index];
      expect(diagonalCell.find("a").exists()).toBe(false);
      expect(diagonalCell.find(".matrix-page__cell--diagonal").exists()).toBe(true);
    });
  });

  it("row=4-4-2, col=4-2-3-1（overallEdge=B、列有利）のセルが列有利の色クラスとto属性を持つ", () => {
    const wrapper = mountMatrix();
    const rowIndex = realFormations.findIndex((f) => f.id === "4-4-2");
    const colIndex = realFormations.findIndex((f) => f.id === "4-2-3-1");
    const cell = wrapper.findAll("tbody tr")[rowIndex].findAll("td")[colIndex];
    const link = cell.find("a");
    expect(link.exists()).toBe(true);
    expect(link.attributes("href")).toBe("/compare/4-4-2/4-2-3-1");
    expect(cell.find(".matrix-page__cell--col").exists()).toBe(true);
    expect(cell.find(".matrix-page__cell--row").exists()).toBe(false);
  });

  it("row=4-2-3-1, col=4-4-2（呼び出し順が逆転しoverallEdgeがAへ反転、行有利）のセルが行有利の色クラスを持つ", () => {
    const wrapper = mountMatrix();
    const rowIndex = realFormations.findIndex((f) => f.id === "4-2-3-1");
    const colIndex = realFormations.findIndex((f) => f.id === "4-4-2");
    const cell = wrapper.findAll("tbody tr")[rowIndex].findAll("td")[colIndex];
    const link = cell.find("a");
    expect(link.attributes("href")).toBe("/compare/4-2-3-1/4-4-2");
    expect(cell.find(".matrix-page__cell--row").exists()).toBe(true);
    expect(cell.find(".matrix-page__cell--col").exists()).toBe(false);
  });

  it("row=4-4-2, col=4-3-3（overallEdge=even）のセルが互角の色クラスを持つ", () => {
    const wrapper = mountMatrix();
    const rowIndex = realFormations.findIndex((f) => f.id === "4-4-2");
    const colIndex = realFormations.findIndex((f) => f.id === "4-3-3");
    const cell = wrapper.findAll("tbody tr")[rowIndex].findAll("td")[colIndex];
    expect(cell.find(".matrix-page__cell--even").exists()).toBe(true);
  });

  it("getMatchupがundefinedを返す組み合わせは、互角とは区別される非リンクの「データ未定義」セルになる", () => {
    // matchups.tsにレコードが無いままformationsだけ追加された状況（データ追加漏れ）を模す。
    // 「互角」と同一視すると、マトリクスは互角と言うのに比較画面は表示不能という
    // 矛盾が静かに発生するため、独立した状態として区別できることを検証する
    state.forceUndefinedFor = { rowId: "4-4-2", colId: "4-2-3-1" };
    const wrapper = mountMatrix();
    const rowIndex = realFormations.findIndex((f) => f.id === "4-4-2");
    const colIndex = realFormations.findIndex((f) => f.id === "4-2-3-1");
    const cell = wrapper.findAll("tbody tr")[rowIndex].findAll("td")[colIndex];
    expect(cell.find(".matrix-page__cell--unknown").exists()).toBe(true);
    expect(cell.find(".matrix-page__cell--even").exists()).toBe(false);
    expect(cell.find(".matrix-page__cell--col").exists()).toBe(false);
    // データ未定義のセルはクリック（比較画面への遷移）できない
    expect(cell.find("a").exists()).toBe(false);
  });

  it("formationsに1件追加されると、コード変更なしに(N+1)×(N+1)のセルへ拡大する", () => {
    // 架空の追加フォーメーションを模すフィクスチャ。id/nameはA-2で4-1-4-1が実在の形として
    // 追加されたため、実データと衝突しない架空値（9-9-9）へ変更している
    // （実在idを使うと realFormations 側の "4-1-4-1" と重複し、Vueのv-for :key が
    // 重複してレンダリングが静かに壊れうる。「架空の追加を模す」意図には実在idは反する）
    const extraFormation: Formation = {
      id: "9-9-9",
      name: "9-9-9",
      description: "テスト用に追加したフォーメーション",
      positions: [],
      stats: { attack: 50, defense: 50, balance: 50, spaceControl: 50, pressIntensity: 50 },
    };
    state.formations = [...realFormations, extraFormation];
    const wrapper = mountMatrix();
    const expectedSize = realFormations.length + 1;
    expect(wrapper.findAll("thead th")).toHaveLength(expectedSize + 1);
    expect(wrapper.findAll("tbody tr")).toHaveLength(expectedSize);
    expect(wrapper.findAll("tbody td")).toHaveLength(expectedSize * expectedSize);
    expect(wrapper.text()).toContain("9-9-9");
  });

  it("「← 戻る」をクリックするとrouter.pushが'/'で1回呼ばれる", async () => {
    const wrapper = mountMatrix();
    await wrapper.find(".matrix-page__back-button").trigger("click");
    expect(pushMock).toHaveBeenCalledTimes(1);
    expect(pushMock).toHaveBeenCalledWith("/");
  });

  // FR-13: 学習進捗トラッキング
  describe("学習進捗", () => {
    beforeEach(() => {
      window.localStorage.clear();
    });

    it("初期状態では確認済み0件、分母は全組み合わせ数（nC2）", () => {
      const wrapper = mountMatrix();
      const n = realFormations.length;
      const totalPairs = (n * (n - 1)) / 2;

      const text = wrapper.find(".matrix-page__progress-text").text();
      expect(text).toContain("確認済み");
      expect(text).toContain("0");
      expect(text).toContain(`全 ${totalPairs} 組み合わせ`);
    });

    it("localStorageに記録済みの組み合わせがあれば、確認済み件数に反映される", async () => {
      const { buildPairKey } = await import("@/data/learningProgress");
      window.localStorage.setItem(
        "formation-lab.learning-progress.v1",
        JSON.stringify({
          viewedPairs: [buildPairKey(realFormations[0].id, realFormations[1].id)],
        }),
      );

      const wrapper = mountMatrix();
      expect(wrapper.find(".matrix-page__progress-text").text()).toContain("確認済み 1");
    });

    it("確認済みの組み合わせのセルにチェック印が付く", async () => {
      const { buildPairKey } = await import("@/data/learningProgress");
      window.localStorage.setItem(
        "formation-lab.learning-progress.v1",
        JSON.stringify({
          viewedPairs: [buildPairKey(realFormations[0].id, realFormations[1].id)],
        }),
      );

      const wrapper = mountMatrix();
      const cell = wrapper.find(
        `a[href="/compare/${realFormations[0].id}/${realFormations[1].id}"]`,
      );
      expect(cell.find(".matrix-page__cell-check").exists()).toBe(true);
      expect(cell.attributes("aria-label")).toContain("確認済み");
    });

    it("未確認のセルにはチェック印が付かず、aria-labelは「未確認」を含む", () => {
      const wrapper = mountMatrix();
      const cell = wrapper.find(
        `a[href="/compare/${realFormations[0].id}/${realFormations[1].id}"]`,
      );
      expect(cell.find(".matrix-page__cell-check").exists()).toBe(false);
      expect(cell.attributes("aria-label")).toContain("未確認");
    });

    it("すべての組み合わせを確認すると完了メッセージが表示される", async () => {
      const { buildPairKey } = await import("@/data/learningProgress");
      const pairs: string[] = [];
      for (let i = 0; i < realFormations.length; i += 1) {
        for (let j = i + 1; j < realFormations.length; j += 1) {
          pairs.push(buildPairKey(realFormations[i].id, realFormations[j].id));
        }
      }
      window.localStorage.setItem(
        "formation-lab.learning-progress.v1",
        JSON.stringify({ viewedPairs: pairs }),
      );

      const wrapper = mountMatrix();
      expect(wrapper.find(".matrix-page__progress-done").exists()).toBe(true);
    });

    it("「進捗を消去」は確認済みが0件のときdisabledになっている", () => {
      const wrapper = mountMatrix();
      expect(wrapper.find(".matrix-page__clear-button").attributes("disabled")).toBeDefined();
    });

    it("「進捗を消去」を押しても即座には消えず、確認を挟む", async () => {
      const { buildPairKey } = await import("@/data/learningProgress");
      window.localStorage.setItem(
        "formation-lab.learning-progress.v1",
        JSON.stringify({
          viewedPairs: [buildPairKey(realFormations[0].id, realFormations[1].id)],
        }),
      );

      const wrapper = mountMatrix();
      await wrapper.find(".matrix-page__clear-button").trigger("click");

      // window.confirm を使わないため、この時点ではまだ消えていない
      expect(wrapper.find(".matrix-page__progress-text").text()).toContain("確認済み 1");
      expect(wrapper.find(".matrix-page__clear-confirm").exists()).toBe(true);
    });

    it("消去を確定すると、進捗が0件になりlocalStorageからも消える", async () => {
      const { buildPairKey } = await import("@/data/learningProgress");
      window.localStorage.setItem(
        "formation-lab.learning-progress.v1",
        JSON.stringify({
          viewedPairs: [buildPairKey(realFormations[0].id, realFormations[1].id)],
        }),
      );

      const wrapper = mountMatrix();
      await wrapper.find(".matrix-page__clear-button").trigger("click");
      await wrapper.find(".matrix-page__clear-confirm").trigger("click");

      expect(wrapper.find(".matrix-page__progress-text").text()).toContain("確認済み 0");
      expect(window.localStorage.getItem("formation-lab.learning-progress.v1")).toBeNull();
    });

    it("消去確認で「やめる」を押すと、進捗は消えない", async () => {
      const { buildPairKey } = await import("@/data/learningProgress");
      window.localStorage.setItem(
        "formation-lab.learning-progress.v1",
        JSON.stringify({
          viewedPairs: [buildPairKey(realFormations[0].id, realFormations[1].id)],
        }),
      );

      const wrapper = mountMatrix();
      await wrapper.find(".matrix-page__clear-button").trigger("click");
      await wrapper.find(".matrix-page__clear-cancel").trigger("click");

      expect(wrapper.find(".matrix-page__progress-text").text()).toContain("確認済み 1");
      expect(wrapper.find(".matrix-page__clear-confirm").exists()).toBe(false);
    });
  });
});
