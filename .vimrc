" 行番号を表示する
set number
" 検索結果をハイライトする
set hlsearch
" vimで開いているファイル名を表示する
set laststatus=2
" タブを表示するときの幅
set tabstop=4
" タブを挿入するときの幅
set shiftwidth=4 

" インサートモードのESCをjjにバインド
inoremap <silent> jj <ESC>


package com.example.orbittrial.vm

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.Flow
import org.orbitmvi.orbit.ContainerHost
import org.orbitmvi.orbit.container

data class SampleState(
    val message: String = "",
    val count: Int = 0
)

interface SampleRepository {
    suspend fun fetchFromServer(): Int

    fun observe(): Flow<Int>
}

class SampleViewModel(
    private val repository: SampleRepository
): ContainerHost<SampleState, Nothing>, ViewModel() {

    private val TAG = SampleViewModel::class.simpleName

    override val container = viewModelScope.container<SampleState, Nothing>(
        SampleState()
    ) {
        intent {
            repository.observe().collect { value ->
                reduce {
                    state.copy(count = value)
                }
            }
        }
    }

    fun onIncrement() = intent {
        reduce {
            state.copy(count = state.count + 1)
        }
    }

    fun onLoad() = intent {
        try {
            val value = repository.fetchFromServer()
            reduce {
                state.copy(
                    count = value
                )
            }
        } catch (t: Throwable) {
        }
    }
}


package com.example.orbittrial.vm

import io.mockk.coEvery
import io.mockk.mockk
import org.junit.Test
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.orbitmvi.orbit.test.test

@OptIn(ExperimentalCoroutinesApi::class)
class SampleViewModelTest {

    private val repository = mockk<SampleRepository>(relaxed = true)
    private lateinit var vm: SampleViewModel

    @Before
    fun setUp() {
        vm = SampleViewModel(repository)
    }

    @Test
    fun test_onIncrement() = runTest {
        vm.test(this) {
            coEvery {
                repository.observe()
            } returns flowOf(5)

            advanceUntilIdle()

            containerHost.onIncrement()

            expectState { copy(count = 6) }
        }
    }

}

