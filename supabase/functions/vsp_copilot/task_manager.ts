// Task Manager with Active + Parked Task Stack
// Prevents Sticky Booking Task trap by supporting suspend, park, resume, and switch semantics.

export type TaskType =
  | "booking_create"
  | "booking_inspect"
  | "booking_modify"
  | "booking_cancel"
  | "payment_reconcile"
  | "tournament_browse"
  | "challenge_browse"
  | "general_inquiry";

export type TaskLifecycle =
  | "created"
  | "active"
  | "paused"
  | "resumed"
  | "completed"
  | "cancelled"
  | "expired";

export interface TaskRecord {
  id: string;
  type: TaskType;
  lifecycle: TaskLifecycle;
  state_snapshot: Record<string, any>;
  version: number;
  created_at: string;
  last_activity_at: string;
  description: string;
}

export interface TaskManagerState {
  active_task: TaskRecord | null;
  parked_tasks: TaskRecord[];
}

export function initializeTaskManager(existing?: Partial<TaskManagerState>): TaskManagerState {
  return {
    active_task: existing?.active_task ?? null,
    parked_tasks: Array.isArray(existing?.parked_tasks) ? existing!.parked_tasks : [],
  };
}

export function createTaskRecord(type: TaskType, stateSnapshot: Record<string, any>, description = ""): TaskRecord {
  const now = new Date().toISOString();
  return {
    id: `task_${type}_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
    type,
    lifecycle: "active",
    state_snapshot: { ...stateSnapshot },
    version: 1,
    created_at: now,
    last_activity_at: now,
    description: description || type,
  };
}

export function parkActiveTask(manager: TaskManagerState): TaskRecord | null {
  if (!manager.active_task) return null;
  const task = manager.active_task;
  task.lifecycle = "paused";
  task.last_activity_at = new Date().toISOString();
  task.version += 1;

  // Avoid duplicate parking
  const existingIdx = manager.parked_tasks.findIndex(t => t.id === task.id);
  if (existingIdx >= 0) {
    manager.parked_tasks[existingIdx] = task;
  } else {
    // Keep max 5 parked tasks
    manager.parked_tasks.unshift(task);
    if (manager.parked_tasks.length > 5) {
      manager.parked_tasks = manager.parked_tasks.slice(0, 5);
    }
  }

  manager.active_task = null;
  return task;
}

export function resumeParkedTask(manager: TaskManagerState, targetType?: TaskType): TaskRecord | null {
  if (manager.parked_tasks.length === 0) return null;

  let chosenIdx = 0;
  if (targetType) {
    const idx = manager.parked_tasks.findIndex(t => t.type === targetType);
    if (idx >= 0) chosenIdx = idx;
  }

  // If there is currently an active task that is not completed, park it first
  if (manager.active_task && manager.active_task.lifecycle === "active") {
    parkActiveTask(manager);
  }

  const [resumedTask] = manager.parked_tasks.splice(chosenIdx, 1);
  resumedTask.lifecycle = "resumed";
  resumedTask.last_activity_at = new Date().toISOString();
  resumedTask.version += 1;
  manager.active_task = resumedTask;

  return resumedTask;
}

export function completeActiveTask(manager: TaskManagerState): void {
  if (manager.active_task) {
    manager.active_task.lifecycle = "completed";
    manager.active_task.last_activity_at = new Date().toISOString();
    manager.active_task = null;
  }
}

export function cancelActiveTask(manager: TaskManagerState): void {
  if (manager.active_task) {
    manager.active_task.lifecycle = "cancelled";
    manager.active_task.last_activity_at = new Date().toISOString();
    manager.active_task = null;
  }
}
