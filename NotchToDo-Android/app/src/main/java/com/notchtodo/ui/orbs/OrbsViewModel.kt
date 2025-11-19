package com.notchtodo.ui.orbs

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.notchtodo.data.repository.OrbRepository
import com.notchtodo.domain.model.Orb
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OrbsViewModel @Inject constructor(
    private val orbRepository: OrbRepository
) : ViewModel() {

    private val _orbs = MutableStateFlow<List<Orb>>(emptyList())
    val orbs: StateFlow<List<Orb>> = _orbs.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    init {
        loadOrbs()
    }

    private fun loadOrbs() {
        viewModelScope.launch {
            orbRepository.observeAllOrbs().collect { orbList ->
                _orbs.value = orbList
                _isLoading.value = false
            }
        }
    }
}
