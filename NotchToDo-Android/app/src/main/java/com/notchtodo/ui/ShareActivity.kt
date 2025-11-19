package com.notchtodo.ui

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.notchtodo.data.repository.TaskRepository
import com.notchtodo.domain.model.Task
import com.notchtodo.ui.theme.NotchToDoTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class ShareActivity : ComponentActivity() {

    @Inject
    lateinit var taskRepository: TaskRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sharedText = when (intent?.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    intent.getStringExtra(Intent.EXTRA_TEXT)
                } else null
            }
            else -> null
        }

        setContent {
            NotchToDoTheme {
                Surface {
                    if (sharedText != null) {
                        ShareDialog(
                            text = sharedText,
                            onSave = { title ->
                                val scope = rememberCoroutineScope()
                                scope.launch {
                                    val task = Task.create(title)
                                    taskRepository.createTask(task)
                                    finish()
                                }
                            },
                            onDismiss = { finish() }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun ShareDialog(
    text: String,
    onSave: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var taskTitle by remember { mutableStateOf(text) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add to NotchToDo") },
        text = {
            OutlinedTextField(
                value = taskTitle,
                onValueChange = { taskTitle = it },
                label = { Text("Task Title") },
                modifier = Modifier.fillMaxWidth()
            )
        },
        confirmButton = {
            TextButton(
                onClick = { onSave(taskTitle) },
                enabled = taskTitle.isNotBlank()
            ) {
                Text("Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
