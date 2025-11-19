package com.notchtodo.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.notchtodo.data.repository.AuthRepository
import com.notchtodo.data.repository.OrbRepository
import com.notchtodo.data.repository.TaskRepository
import com.notchtodo.util.DebugLog
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val taskRepository: TaskRepository,
    private val orbRepository: OrbRepository
) : ViewModel() {

    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing.asStateFlow()

    fun triggerSync() {
        viewModelScope.launch {
            _isSyncing.value = true
            try {
                DebugLog.log("Manual sync triggered", DebugLog.Category.SYNC)

                // Sync orbs first
                orbRepository.syncOrbs()

                // Then sync tasks
                taskRepository.syncTasks()

                DebugLog.log("Manual sync completed", DebugLog.Category.SYNC)
            } catch (e: Exception) {
                DebugLog.error("Manual sync failed", e, DebugLog.Category.SYNC)
            } finally {
                _isSyncing.value = false
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            authRepository.signOut()
        }
    }
}
