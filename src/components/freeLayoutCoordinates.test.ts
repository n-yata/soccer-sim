import { describe, it, expect } from "vitest";
import { xToCy, cyToX, depthToCx, cxToDepth, clampToPitchRange } from "./freeLayoutCoordinates";

describe("freeLayoutCoordinates", () => {
  it.each([0, 25, 50, 75, 100])("x=%i: x→cy→xの往復が元の値に戻る", (x) => {
    expect(cyToX(xToCy(x))).toBeCloseTo(x);
  });

  it.each([0, 25, 50, 75, 100])("Aチーム y=%i: y→cx→yの往復が元の値に戻る", (y) => {
    expect(cxToDepth("A", depthToCx("A", y))).toBeCloseTo(y);
  });

  it.each([0, 25, 50, 75, 100])("Bチーム y=%i: y→cx→yの往復が元の値に戻る", (y) => {
    expect(cxToDepth("B", depthToCx("B", y))).toBeCloseTo(y);
  });

  it("Aチームは自陣(y=0)がcx=0側、Bチームは自陣(y=0)がcx=260側になる（鏡映）", () => {
    expect(depthToCx("A", 0)).toBeCloseTo(0);
    expect(depthToCx("B", 0)).toBeCloseTo(260);
  });

  it("両チームともy=100(敵陣)でcx=130(中央)に到達する", () => {
    expect(depthToCx("A", 100)).toBeCloseTo(130);
    expect(depthToCx("B", 100)).toBeCloseTo(130);
  });

  describe("clampToPitchRange", () => {
    it("0-100の範囲内の値はそのまま返す", () => {
      expect(clampToPitchRange(50)).toBe(50);
    });

    it("0未満は0にクランプする", () => {
      expect(clampToPitchRange(-10)).toBe(0);
    });

    it("100を超える値は100にクランプする", () => {
      expect(clampToPitchRange(150)).toBe(100);
    });
  });
});
