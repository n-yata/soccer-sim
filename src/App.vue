<template>
  <AppHeader :show-cup-link="showCupLink" />
  <router-view />
</template>

<script setup lang="ts">
import { computed } from "vue";
import AppHeader from "@/components/AppHeader.vue";
import { CUP_REQUIRED_FORMATION_COUNT, formations } from "@/data/formations";

const showCupLink = computed(() => formations.length === CUP_REQUIRED_FORMATION_COUNT);
</script>
