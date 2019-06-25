require "test_helper"
require "refer/builds_ident_tokens"
require "refer/value/definition"

module Refer
  class BuildsIdentTokensTest < ReferTest
    FILE = "foo.rb"

    def subject
      @subject ||= BuildsIdentTokens.new
    end

    def test_naked_module
      node = RubyVM::AbstractSyntaxTree.parse <<~RUBY
        module Neet
        end
      RUBY
      root_node = node.children.last
      root_token = token_for(root_node)

      result = subject.call(root_node, root_token)

      assert_equal 1, result.size
      assert_equal Value::Reference.new(
        name: :Neet,
        node_type: Value::Reference::TYPES[:double_colon],
        parent: root_token,
        file: FILE,
        line: 1,
        column: 7
      ), result.first
      assert_equal result, root_token.identifiers
      assert_equal :Neet, root_token.name
      assert_equal "Neet", root_token.literal_name
      assert_equal "Neet", root_token.full_name
    end

    def test_nested_module
      node = RubyVM::AbstractSyntaxTree.parse <<~RUBY
        module Super::Neet
        end
      RUBY
      root_node = node.children.last
      root_token = token_for(root_node)

      result = subject.call(root_node, root_token)

      assert_equal 2, result.size
      assert_equal Value::Reference.new(
        name: :Super,
        node_type: Value::Reference::TYPES[:constant],
        parent: root_token,
        file: FILE,
        line: 1,
        column: 7
      ), result[0]
      assert_equal Value::Reference.new(
        name: :Neet,
        node_type: Value::Reference::TYPES[:double_colon],
        parent: root_token,
        file: FILE,
        line: 1,
        column: 7
      ), result[1]
      assert_equal result, root_token.identifiers
      assert_equal :Neet, root_token.name
      assert_equal "Super::Neet", root_token.literal_name
      assert_equal "Super::Neet", root_token.full_name
    end

    def test_2_deep_nested_module
      node = RubyVM::AbstractSyntaxTree.parse <<~RUBY
        module Really::Quite
          module Super::Duper::Neet
          end
        end
      RUBY
      quite_node = node.children.last
      quite_token = token_for(quite_node)
      subject.call(quite_node, quite_token) # for the side effect…
      root_node = node.children[2].children[1].children[2].children[1]
      root_token = token_for(root_node, quite_token)

      result = subject.call(root_node, root_token)

      assert_equal 3, result.size
      assert_equal Value::Reference.new(
        name: :Super,
        node_type: Value::Reference::TYPES[:constant],
        parent: root_token,
        file: FILE,
        line: 2,
        column: 9
      ), result[0]
      assert_equal Value::Reference.new(
        name: :Duper,
        node_type: Value::Reference::TYPES[:double_colon],
        parent: root_token,
        file: FILE,
        line: 2,
        column: 9
      ), result[1]
      assert_equal Value::Reference.new(
        name: :Neet,
        node_type: Value::Reference::TYPES[:double_colon],
        parent: root_token,
        file: FILE,
        line: 2,
        column: 9
      ), result[2]
      assert_equal result, root_token.identifiers
      assert_equal :Neet, root_token.name
      assert_equal "Super::Duper::Neet", root_token.literal_name
      assert_equal "Really::Quite::Super::Duper::Neet", root_token.full_name
    end

    def test_instance_method
      node = RubyVM::AbstractSyntaxTree.parse <<~RUBY
        def foo
        end
      RUBY
      root_node = node.children.last
      root_token = token_for(root_node)

      result = subject.call(root_node, root_token)

      assert_equal 0, result.size
      assert_equal result, root_token.identifiers
      assert_equal :foo, root_token.name
      assert_equal "foo", root_token.literal_name
      assert_equal "foo", root_token.full_name
    end

    private

    # reinvented here to avoid indirectly calling the thing under test
    def token_for(node, parent = nil)
      return unless (type = Value::Definition::TYPES.values.find { |d| node.type == d.ast_type })

      Value::Definition.new(
        name: type.name_finder.call(node),
        node_type: type,
        parent: parent,
        file: FILE,
        line: node.first_lineno,
        column: node.first_column
      )
    end
  end
end
