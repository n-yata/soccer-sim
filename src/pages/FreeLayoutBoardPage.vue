<template>
  <main class="board-page">
    <PageHeader
      title="自由配置ボード"
      subtitle="選手とボールを動かして、自由に配置を試してみよう"
    />
    <div class="board-page__body">
      <div class="board-page__controls">
        <section
          v-for="team in teams"
          :key="team"
          :aria-label="teamLabel(team)"
          class="board-page__team"
        >
          <label
            :for="`board-formation-${team.toLowerCase()}`"
            :class="`board-page__label--${team.toLowerCase()}`"
          >
            {{ teamLabel(team) }}の陣形
          </label>
          <select
            :id="`board-formation-${team.toLowerCase()}`"
            :value="board[team].id"
            @change="selectFormation(team, ($event.target as HTMLSelectElement).value)"
          >
            <option v-for="formation in formations" :key="formation.id" :value="formation.id">
              {{ formation.name }}
            </option>
          </select>
          <button
            type="button"
            :data-testid="`reset-${team.toLowerCase()}`"
            @click="resetTeam(team)"
          >
            {{ teamLabel(team) }}をリセット
          </button>
        </section>
      </div>
      <div class="board-page__ball-controls">
        <button type="button" data-testid="reset-ball" @click="resetBall">
          ボールを中央に戻す
        </button>
      </div>
      <p id="board-instructions" class="board-page__instructions">
        両チームの選手とボールをドラッグで動かせます。Tabで選び、矢印キーでも移動できます。
        配置はこの端末に保存されます。
      </p>
      <div class="board-page__pitch" aria-describedby="board-instructions">
        <FreeLayoutPitchDiagram
          :key="`${board.A.id}:${board.B.id}:${pitchRevision}`"
          :formation-a="board.A"
          :formation-b="board.B"
          @update-position="updatePosition"
          @update-position-end="savePosition"
        />
        <BoardBall
          :key="ballRevision"
          :position="ballPosition"
          @update-position="ballPosition = $event"
          @update-position-end="saveBoardBallPosition"
        />
      </div>
      <div class="board-page__directions">
        <span>青チームの攻撃方向 →</span>
        <span>← 赤チームの攻撃方向</span>
      </div>
    </div>
  </main>
</template>

<script setup lang="ts">
import { reactive, ref } from "vue";
import PageHeader from "@/components/PageHeader.vue";
import FreeLayoutPitchDiagram from "@/components/FreeLayoutPitchDiagram.vue";
import BoardBall from "@/components/BoardBall.vue";
import {
  BOARD_BALL_CENTER,
  loadBoardBallPosition,
  saveBoardBallPosition,
} from "@/data/boardBallStorage";
import { formations } from "@/data/formations";
import {
  applyOverrides,
  clearFormationOverride,
  savePositionOverride,
} from "@/data/freeLayoutStorage";
import type { Formation } from "@/types/formation";

type Team = "A" | "B";
const teams: Team[] = ["A", "B"];
const BOARD_STORAGE_KEY = "formation-lab.board-layout-overrides.v1";

// 同じ陣形同士でも青・赤の編集を分離し、比較画面の保存先とも共有しない。
function layoutId(team: Team, formationId: string): string {
  return `${team}:${formationId}`;
}

function restoreFormation(team: Team, formation: Formation): Formation {
  return {
    ...formation,
    positions: applyOverrides(formation.positions, layoutId(team, formation.id), BOARD_STORAGE_KEY),
  };
}

const board = reactive<Record<Team, Formation>>({
  A: restoreFormation("A", formations[0]),
  B: restoreFormation("B", formations[1] ?? formations[0]),
});
const pitchRevision = ref(0);
const ballPosition = ref(loadBoardBallPosition());
const ballRevision = ref(0);

function resetBall(): void {
  // ボールの操作状態だけを破棄し、リセット前の確定イベントが後から保存されるのを防ぐ。
  ballRevision.value++;
  ballPosition.value = { ...BOARD_BALL_CENTER };
  saveBoardBallPosition(ballPosition.value);
}

function teamLabel(team: Team): string {
  return team === "A" ? "青チーム" : "赤チーム";
}

function selectFormation(team: Team, formationId: string): void {
  const formation = formations.find((item) => item.id === formationId);
  if (formation) board[team] = restoreFormation(team, formation);
}

function resetTeam(team: Team): void {
  clearFormationOverride(layoutId(team, board[team].id), BOARD_STORAGE_KEY);
  const formation = formations.find((item) => item.id === board[team].id);
  if (formation) {
    board[team] = {
      ...formation,
      positions: formation.positions.map((position) => ({ ...position })),
    };
    // リセット前のドラッグ・キー操作が確定して保存されるのを防ぐ。
    pitchRevision.value++;
  }
}

function updatePosition(team: Team, positionId: string, x: number, y: number): void {
  if (!Number.isFinite(x) || !Number.isFinite(y)) return;
  board[team].positions = board[team].positions.map((position) =>
    position.id === positionId
      ? { ...position, x: Math.min(100, Math.max(0, x)), y: Math.min(100, Math.max(0, y)) }
      : position,
  );
}

function savePosition(team: Team, positionId: string, x: number, y: number): void {
  if (!board[team].positions.some((position) => position.id === positionId)) return;
  if (!Number.isFinite(x) || !Number.isFinite(y)) return;
  savePositionOverride(layoutId(team, board[team].id), positionId, x, y, BOARD_STORAGE_KEY);
}
</script>

<style scoped>
.board-page__body {
  max-width: var(--width-wide);
  margin: 0 auto;
  padding: var(--space-xl) var(--gutter);
}

.board-page__controls {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--space-lg);
}

.board-page__team {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-sm);
}

.board-page__team label {
  width: 100%;
  font-weight: var(--weight-semibold);
}

.board-page__label--a {
  color: var(--color-team-a-accent-text);
}
.board-page__label--b {
  color: var(--color-team-b-accent-text);
}

.board-page__team select,
.board-page__team button,
.board-page__ball-controls button {
  min-height: 44px;
  padding: var(--space-xs) var(--space-md);
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-sm);
  background: var(--color-surface);
  color: var(--color-text);
  font: inherit;
  cursor: pointer;
}

.board-page__team select {
  flex: 1;
  min-width: 0;
}
.board-page__team button:hover {
  background: var(--color-surface-hover);
}
.board-page__instructions {
  color: var(--color-text-sub);
  font-size: var(--font-sm);
  margin: var(--space-lg) 0;
}
.board-page__pitch {
  position: relative;
  max-width: 960px;
  margin: 0 auto;
}
.board-page__pitch :deep(.free-layout-pitch) {
  display: block;
}
.board-page__ball-controls {
  margin-top: var(--space-md);
}
.board-page__directions {
  display: flex;
  justify-content: space-between;
  gap: var(--space-md);
  margin-top: var(--space-sm);
  font-size: var(--font-sm);
  color: var(--color-text-muted);
}

@media (max-width: 640px) {
  .board-page__body {
    padding: var(--space-lg) var(--gutter-mobile);
  }
  .board-page__controls {
    grid-template-columns: 1fr;
  }
}
</style>
