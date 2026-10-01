<template>
  <div class="app-shell">
    <AppHeader />
    <router-view />
  </div>
</template>

<script setup lang="ts">
import AppHeader from "@/components/AppHeader.vue";
</script>

<style scoped>
.app-shell {
  min-height: 100vh;
}
</style>
