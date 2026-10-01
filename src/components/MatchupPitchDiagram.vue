<template>
  <svg
    viewBox="-5 0 270 160"
    class="matchup-pitch"
    role="img"
    :aria-label="`${formationA.name}と${formationB.name}のフォーメーション配置を重ねたピッチ図`"
  >
    <defs>
      <!-- 芝生の演出は維持しつつ、上下の明度差を縮めて主張を弱める。
           stop-colorはCSSプロパティとしても有効なため、クラス経由でトークンを参照する -->
      <linearGradient id="matchupPitchGradient" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" class="matchup-pitch__gradient-start" />
        <stop offset="100%" class="matchup-pitch__gradient-end" />
      </linearGradient>
    </defs>
    <rect x="-5" y="0" width="270" height="160" class="matchup-pitch__field" />
    <rect
      v-for="stripe in stripes"
      :key="stripe.x"
      :x="stripe.x"
      y="0"
      :width="stripeWidth"
      height="160"
      class="matchup-pitch__stripe"
    />
    <rect x="-4" y="1" width="268" height="158" class="matchup-pitch__outline" />
    <line x1="130" y1="0" x2="130" y2="160" class="matchup-pitch__line" />
    <circle cx="130" cy="80" r="25" class="matchup-pitch__line-shape" />
    <rect x="-5" y="40" width="35" height="80" class="matchup-pitch__line-shape" />
    <rect x="230" y="40" width="35" height="80" class="matchup-pitch__line-shape" />
    <g class="matchup-pitch__team matchup-pitch__team--a">
      <g v-for="item in itemsA" :key="`${item.team}-${item.position.id}`">
        <circle :cx="item.cx" :cy="item.cy" r="4.5" class="matchup-pitch__player blue" />
        <text :x="item.cx" :y="item.cy - 7" text-anchor="middle" class="matchup-pitch__label">
          {{ item.position.label }}
        </text>
      </g>
    </g>
    <g class="matchup-pitch__team matchup-pitch__team--b">
      <g v-for="item in itemsB" :key="`${item.team}-${item.position.id}`">
        <circle :cx="item.cx" :cy="item.cy" r="4.5" class="matchup-pitch__player red" />
        <text :x="item.cx" :y="item.cy - 7" text-anchor="middle" class="matchup-pitch__label">
          {{ item.position.label }}
        </text>
      </g>
    </g>
  </svg>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { Formation, Position } from "@/types/formation";

// ピッチの芝生ストライプ演出用。装飾のみで選手配置ロジックとは無関係
const stripeWidth = 270 / 8;
const stripes = [1, 3, 5, 7].map((i) => ({ x: -5 + i * stripeWidth }));

const props = defineProps<{
  formationA: Formation;
  formationB: Formation;
}>();

interface Item {
  team: "A" | "B";
  position: Position;
  cx: number;
  cy: number;
}

// GKの深さ（cx）は青チームと赤チームで独立した固定位置を持つ。DF/FWは「補間の両端アンカー」
// であり、実際のDF/FW列のcxはbuildTeamItemsでこの値を基準にy座標から算出するため、
// フォーメーションによってこの定数そのものとは多少ずれる（後述）。青はGK(0)から右へ、
// 赤はGK(260)から左へ展開するが、その展開率は非対称にしてある。青の攻撃陣（FW）が
// 赤の守備陣（DF）に近づき、赤の攻撃陣（FW）が青の守備陣（DF）に近づくことで、
// 「両チームが向き合って対戦している」実際のサッカーの力学を表現する
const colXByTeam: Record<"A" | "B", { GK: number; DF: number; FW: number }> = {
  A: { GK: 0, DF: 39.4, FW: 179.5 },
  B: { GK: 260, DF: 215.2, FW: 74.1 },
};

// DF/FWの間に並ぶ列の数はフォーメーションごとに異なる（例: 4-2-3-1はDM2枚+AM3枚で
// 中盤が2列に分かれる、4-1-2-1-2は中盤が3層に分かれる）。typeはGK/DF/MF/FWの4種類しか
// 持たないため、typeだけでは列数を決められない。y座標のギャップでクラスタリングして
// 実際の陣形が何列で構成されているかを動的に求める
const Y_CLUSTER_GAP_THRESHOLD = 10;

function clusterOutfieldByY(positions: Position[]): Position[][] {
  const sorted = [...positions].sort((a, b) => a.y - b.y);
  const clusters: Position[][] = [];
  let current: Position[] = [];
  for (const position of sorted) {
    const prev = current[current.length - 1];
    if (prev && position.y - prev.y > Y_CLUSTER_GAP_THRESHOLD) {
      clusters.push(current);
      current = [];
    }
    current.push(position);
  }
  if (current.length > 0) clusters.push(current);
  return clusters;
}

// 選手の丸そのもののサイズ（半径4.5の2倍。circle要素のr属性と対応）。中心間距離が
// これを下回ると、色が違っても2チームの選手として見分けられなくなる
const PLAYER_MARKER_DIAMETER = 9;

function buildTeamItems(team: "A" | "B", formation: Formation): Item[] {
  const result: Item[] = [];
  const gk = formation.positions.find((p) => p.type === "GK");
  const outfield = formation.positions.filter((p) => p.type !== "GK");
  const clusters = clusterOutfieldByY(outfield);
  const { DF: dfX, FW: fwX } = colXByTeam[team];
  const cyById = new Map<string, number>();

  // 列のcxは「何番目の列か」ではなく、実際のy座標がDF〜FWの範囲のどこに位置するかで
  // 決める。列番号（等間隔の指数）だけで決めると、列数の異なるフォーメーション同士を
  // 対戦させたときに、片方の中間列がもう片方の中間列と偶然ほぼ同じcxに重なることがある
  // （例: 3列フォーメーションのMF＝中央と、5列フォーメーションのAM＝4/5地点が近接する
  // ケースが実データで発生し、選手の丸がほぼ重なって見分けられなくなっていた）。
  // 実データのyに基づかせることで、フォーメーションごとに列の間隔が実際の陣形の
  // 疎密を反映し、偶然の重なりが起きにくくなる
  const outfieldMinY = Math.min(...outfield.map((p) => p.y));
  const outfieldMaxY = Math.max(...outfield.map((p) => p.y));
  const yRange = outfieldMaxY - outfieldMinY;

  // 列内の選手は幅方向の中心線（cy=80）を軸に均等配置する。青チーム・赤チームで
  // 同じ基準を使うことで、同一フォーメーション同士の対戦ではDFライン・GKの高さが
  // 左右対称になる（チームごとに基準をずらすと、衝突が実際には起きない組み合わせでも
  // 常にチーム間でわずかな上下ズレが生じてしまう）。列数が異なる陣形同士の対戦などで
  // 両チームの選手が偶然近接するケースは、両チームの配置が揃ったあとに
  // resolveOverlaps で衝突する選手だけを個別に押し離して解消する
  clusters.forEach((cluster) => {
    const avgY = cluster.reduce((sum, p) => sum + p.y, 0) / cluster.length;
    const t = yRange === 0 ? 0 : (avgY - outfieldMinY) / yRange;
    const cx = dfX + (fwX - dfX) * t;
    const sorted = [...cluster].sort((a, b) => a.x - b.x);
    sorted.forEach((position, index) => {
      const cy = 10 + ((index + 0.5) / sorted.length) * 140;
      cyById.set(position.id, cy);
      result.push({ team, position, cx, cy });
    });
  });

  // GKは、自チームのDFラインの中で最も中央（x=50）に近い選手（センターバック）と
  // 同じ高さに合わせる（敵チームの選手がGKの正面〈同じ高さ〉に来る回帰を防ぐ）。
  // 同着（例: CBが2枚とも同じ距離）の場合は、それらのcyの平均を使うことで、
  // GKがどちらか一方に偏らず、DFライン全体の中心に来るようにする
  if (gk) {
    let minDistance = Infinity;
    let centermostCys: number[] = [];
    for (const position of formation.positions.filter((p) => p.type === "DF")) {
      const distance = Math.abs(position.x - 50);
      const cy = cyById.get(position.id) ?? 80;
      if (distance < minDistance) {
        minDistance = distance;
        centermostCys = [cy];
      } else if (distance === minDistance) {
        centermostCys.push(cy);
      }
    }
    const gkCy =
      centermostCys.length > 0
        ? centermostCys.reduce((a, b) => a + b, 0) / centermostCys.length
        : 80;
    result.push({ team, position: gk, cx: colXByTeam[team].GK, cy: gkCy });
  }
  return result;
}

// buildTeamItemsは列（cx）をy座標の相対位置から、cyは青チーム・赤チーム共通の基準
// （中心線cy=80を軸にした均等配置）から決めるため、フォーメーションの組み合わせに
// よっては両チームの選手が偶然近接するケースが残る（cxの差が小さいまま、cyも
// たまたま近い値になる場合）。そのケースをここで個別に潰す。cxは陣形の深さを表す値
// なので変えず、cyだけを押し離すことで最低限の距離を確保する。目標値は
// PLAYER_MARKER_DIAMETERちょうどではなく、選手ラベルの分の余白を加えたもの。ラベルは
// 選手の丸の中心から7上（テンプレートの`cy - 7`）に描画されるため、ちょうど直径分しか
// 離れていないと、丸同士は重ならなくても片方のラベル文字がもう片方の丸に重なって見える
const MIN_CROSS_TEAM_DISTANCE = PLAYER_MARKER_DIAMETER + 7;

// 押し離しは片方のチームだけを動かすのではなく、両チームを半分ずつ逆方向に動かす。
// 片方だけを動かす実装だと、同一フォーメーション同士の対戦（本来は左右対称）でも、
// 衝突が起きた列だけ一方のチームに偏ってずれてしまう。また、1つのb（片方の選手）が
// 複数のaと衝突する場合、逐次的に押し離すと後の補正が先の補正を打ち消して往復し、
// 収束しないことがあるため、複数回のパスで少しずつ歩み寄らせる
const OVERLAP_RESOLUTION_PASSES = 5;

function resolveOverlaps(itemsA: Item[], itemsB: Item[]): void {
  for (let pass = 0; pass < OVERLAP_RESOLUTION_PASSES; pass++) {
    for (const b of itemsB) {
      for (const a of itemsA) {
        const dx = b.cx - a.cx;
        if (Math.abs(dx) >= MIN_CROSS_TEAM_DISTANCE) continue;
        const currentDy = b.cy - a.cy;
        const distance = Math.hypot(dx, currentDy);
        if (distance >= MIN_CROSS_TEAM_DISTANCE) continue;
        const requiredDy = Math.sqrt(MIN_CROSS_TEAM_DISTANCE ** 2 - dx * dx);
        const direction = currentDy >= 0 ? 1 : -1;
        const halfDeficit = (direction * (requiredDy - Math.abs(currentDy))) / 2;
        a.cy -= halfDeficit;
        b.cy += halfDeficit;
      }
    }
  }
}

// 対戦演出（チームごとのスライドイン）のため、テンプレート側では別々の<g>に
// グルーピングしたいが、resolveOverlapsは両チームを同時に押し離すため、
// 1つのcomputedでまとめて算出してから分解する
const resolvedItems = computed(() => {
  const a = buildTeamItems("A", props.formationA);
  const b = buildTeamItems("B", props.formationB);
  resolveOverlaps(a, b);
  return { a, b };
});
const itemsA = computed(() => resolvedItems.value.a);
const itemsB = computed(() => resolvedItems.value.b);
</script>

<style scoped>
.matchup-pitch {
  width: 100%;
  height: auto;
}

.matchup-pitch__field {
  fill: url(#matchupPitchGradient);
}

.matchup-pitch__gradient-start {
  stop-color: var(--color-pitch);
}

.matchup-pitch__gradient-end {
  stop-color: var(--color-pitch-dark);
}

.matchup-pitch__stripe {
  fill: var(--color-text);
  fill-opacity: 0.06;
}

.matchup-pitch__outline {
  fill: none;
  stroke: var(--color-surface);
  stroke-opacity: 0.7;
  stroke-width: 1;
}

.matchup-pitch__line {
  stroke: var(--color-surface);
  stroke-opacity: 0.7;
  stroke-width: 0.8;
}

.matchup-pitch__line-shape {
  fill: none;
  stroke: var(--color-surface);
  stroke-opacity: 0.7;
  stroke-width: 0.8;
}

.matchup-pitch__player.blue {
  fill: var(--color-team-a);
  stroke: var(--color-surface);
  stroke-width: 1;
  filter: drop-shadow(var(--shadow-token));
}

.matchup-pitch__player.red {
  fill: var(--color-team-b);
  stroke: var(--color-surface);
  stroke-width: 1;
  filter: drop-shadow(var(--shadow-token));
}

.matchup-pitch__label {
  font-size: 3.5px;
  font-weight: var(--weight-semibold);
  fill: var(--color-surface);
  paint-order: stroke;
  stroke: var(--color-text);
  stroke-width: 0.6px;
}

/* 対戦演出: 両陣形が画面外からスライドインして噛み合う */
.matchup-pitch__team--a {
  animation: matchup-slide-in-left 0.7s ease-out both;
}

.matchup-pitch__team--b {
  animation: matchup-slide-in-right 0.7s ease-out both;
}

@keyframes matchup-slide-in-left {
  from {
    transform: translateX(-120px);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

@keyframes matchup-slide-in-right {
  from {
    transform: translateX(120px);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .matchup-pitch__team--a,
  .matchup-pitch__team--b {
    animation: none;
  }
}
</style>
