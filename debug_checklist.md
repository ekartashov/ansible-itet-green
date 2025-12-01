# Roo Tools Debugging Checklist

## Pre-Debugging Preparation

- [ ] Verify workspace directory and permissions
- [ ] Check if ConPort database is accessible
- [ ] Confirm all required tools are available
- [ ] Set up test environment (temporary directory)

## File Operation Tools Testing

### write_to_file
- [ ] Test file creation with basic content
- [ ] Verify file content is written correctly
- [ ] Test file overwriting capability
- [ ] Check file permissions and path handling

### apply_diff
- [ ] Test simple content replacement
- [ ] Verify exact content matching requirement
- [ ] Test line number precision
- [ ] Check multi-block replacement capability
- [ ] Verify error handling for mismatched content

### insert_content
- [ ] Test insertion at beginning of file (line 1)
- [ ] Test insertion at middle of file
- [ ] Test insertion at end of file (line 0)
- [ ] Verify content is inserted at correct position
- [ ] Check handling of multi-line content

## ConPort MCP Server Tools Testing

### Context Management
- [ ] Test get_product_context with empty context
- [ ] Test get_active_context with empty context
- [ ] Test update_product_context with new data
- [ ] Test update_active_context with new data
- [ ] Verify context persistence after updates

### Decision Management
- [ ] Test log_decision with minimal arguments
- [ ] Test get_decisions retrieval
- [ ] Test delete_decision_by_id
- [ ] Verify decision persistence

### Progress Management
- [ ] Test log_progress with status and description
- [ ] Test get_progress retrieval
- [ ] Test update_progress
- [ ] Test delete_progress_by_id
- [ ] Verify progress persistence

### System Pattern Management
- [ ] Test log_system_pattern with name and description
- [ ] Test get_system_patterns retrieval
- [ ] Test delete_system_pattern_by_id
- [ ] Verify pattern persistence

### Custom Data Management
- [ ] Test log_custom_data with category, key, and value
- [ ] Test get_custom_data retrieval
- [ ] Test delete_custom_data
- [ ] Verify custom data persistence

### Search and Utility Tools
- [ ] Test search_decisions_fts with sample query
- [ ] Test search_custom_data_value_fts
- [ ] Test semantic_search_conport
- [ ] Test link_conport_items
- [ ] Test get_linked_items
- [ ] Test batch_log_items
- [ ] Test get_item_history
- [ ] Test get_recent_activity_summary
- [ ] Test export_conport_to_markdown
- [ ] Test import_markdown_to_conport

## Error Handling and Edge Cases

- [ ] Test invalid workspace_id
- [ ] Test missing required arguments
- [ ] Test malformed content in apply_diff
- [ ] Test duplicate keys in custom data
- [ ] Test empty content scenarios
- [ ] Test boundary conditions (empty files, large content)

## Performance and Reliability

- [ ] Test tool execution speed
- [ ] Verify concurrent tool usage
- [ ] Check memory usage patterns
- [ ] Test recovery from partial failures
- [ ] Verify data integrity after operations

## Documentation and Examples

- [ ] Document successful usage patterns
- [ ] Record error scenarios and resolutions
- [ ] Create example code snippets for each tool
- [ ] Update tool usage guidelines
- [ ] Add troubleshooting tips

## Post-Testing Cleanup

- [ ] Remove temporary test files
- [ ] Verify no unintended side effects
- [ ] Confirm ConPort database integrity
- [ ] Document any findings for future reference