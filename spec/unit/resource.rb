#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'
require 'puppet/resource'

describe Puppet::Resource do
    [:catalog, :file, :line, :implicit].each do |attr|
        it "should have an #{attr} attribute" do
            resource = Puppet::Resource.new("file", "/my/file")
            resource.should respond_to(attr)
            resource.should respond_to(attr.to_s + "=")
        end
    end

    describe "when initializing" do
        it "should require the type and title" do
            lambda { Puppet::Resource.new }.should raise_error(ArgumentError)
        end

        it "should create a resource reference with its type and title" do
            ref = Puppet::Resource::Reference.new("file", "/f")
            Puppet::Resource::Reference.expects(:new).with("file", "/f").returns ref
            Puppet::Resource.new("file", "/f")
        end

        it "should allow setting of parameters" do
            Puppet::Resource.new("file", "/f", :noop => true)[:noop].should be_true
        end

        it "should tag itself with its type" do
            Puppet::Resource.new("file", "/f").should be_tagged("file")
        end

        it "should tag itself with its title if the title is a valid tag" do
            Puppet::Resource.new("file", "bar").should be_tagged("bar")
        end

        it "should not tag itself with its title if the title is a not valid tag" do
            Puppet::Resource.new("file", "/bar").should_not be_tagged("/bar")
        end
    end

    it "should use the resource reference to determine its type" do
        ref = Puppet::Resource::Reference.new("file", "/f")
        Puppet::Resource::Reference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:type).returns "mytype"
        resource.type.should == "mytype"
    end

    it "should use its resource reference to determine its title" do
        ref = Puppet::Resource::Reference.new("file", "/f")
        Puppet::Resource::Reference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:title).returns "mytitle"
        resource.title.should == "mytitle"
    end

    it "should use its resource reference to produce its canonical reference string" do
        ref = Puppet::Resource::Reference.new("file", "/f")
        Puppet::Resource::Reference.expects(:new).returns ref
        resource = Puppet::Resource.new("file", "/f")
        ref.expects(:to_s).returns "Foo[bar]"
        resource.ref.should == "Foo[bar]"
    end

    it "should be taggable" do
        Puppet::Resource.ancestors.should be_include(Puppet::Util::Tagging)
    end

    describe "when managing parameters" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
        end

        it "should allow setting and retrieving of parameters" do
            @resource[:foo] = "bar"
            @resource[:foo].should == "bar"
        end

        it "should canonicalize retrieved parameter names to treat symbols and strings equivalently" do
            @resource[:foo] = "bar"
            @resource["foo"].should == "bar"
        end

        it "should canonicalize set parameter names to treat symbols and strings equivalently" do
            @resource["foo"] = "bar"
            @resource[:foo].should == "bar"
        end

        it "should set the namevar when asked to set the name" do
            Puppet::Type.type(:file).stubs(:namevar).returns :myvar
            @resource[:name] = "/foo"
            @resource[:myvar].should == "/foo"
        end

        it "should return the namevar when asked to return the name" do
            Puppet::Type.type(:file).stubs(:namevar).returns :myvar
            @resource[:myvar] = "/foo"
            @resource[:name].should == "/foo"
        end

        it "should be able to set the name for non-builtin types" do
            resource = Puppet::Resource.new(:foo, "bar")
            lambda { resource[:name] = "eh" }.should_not raise_error
        end

        it "should be able to return the name for non-builtin types" do
            resource = Puppet::Resource.new(:foo, "bar")
            resource[:name] = "eh"
            resource[:name].should == "eh"
        end

        it "should be able to iterate over parameters" do
            @resource[:foo] = "bar"
            @resource[:fee] = "bare"
            params = {}
            @resource.each do |key, value|
                params[key] = value
            end
            params.should == {:foo => "bar", :fee => "bare"}
        end

        it "should include Enumerable" do
            @resource.class.ancestors.should be_include(Enumerable)
        end

        it "should have a method for testing whether a parameter is included" do
            @resource[:foo] = "bar"
            @resource.should be_has_key(:foo)
            @resource.should_not be_has_key(:eh)
        end

        it "should have a method for providing the list of parameters" do
            @resource[:foo] = "bar"
            @resource[:bar] = "foo"
            keys = @resource.keys
            keys.should be_include(:foo)
            keys.should be_include(:bar)
        end

        it "should have a method for providing the number of parameters" do
            @resource[:foo] = "bar"
            @resource.length.should == 1
        end

        it "should have a method for deleting parameters" do
            @resource[:foo] = "bar"
            @resource.delete(:foo)
            @resource[:foo].should be_nil
        end

        it "should have a method for testing whether the parameter list is empty" do
            @resource.should be_empty
            @resource[:foo] = "bar"
            @resource.should_not be_empty
        end

        it "should be able to produce a hash of all existing parameters" do
            @resource[:foo] = "bar"
            @resource[:fee] = "yay"

            hash = @resource.to_hash
            hash[:foo].should == "bar"
            hash[:fee].should == "yay"
        end

        it "should not provide direct access to the internal parameters hash when producing a hash" do
            hash = @resource.to_hash
            hash[:foo] = "bar"
            @resource[:foo].should be_nil
        end

        it "should use the title as the namevar to the hash if no namevar is present" do
            Puppet::Type.type(:file).stubs(:namevar).returns :myvar
            @resource.to_hash[:myvar].should == "/my/file"
        end

        it "should set :name to the title if :name is not present for non-builtin types" do
            resource = Puppet::Resource.new :foo, "bar"
            resource.to_hash[:name].should == "bar"
        end
    end

    describe "when serializing" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
            @resource["one"] = "test"
            @resource["two"] = "other"
        end

        it "should be able to be dumped to yaml" do
            proc { YAML.dump(@resource) }.should_not raise_error
        end

        it "should produce an equivalent yaml object" do
            text = YAML.dump(@resource)

            newresource = YAML.load(text)
            newresource.title.should == @resource.title
            newresource.type.should == @resource.type
            %w{one two}.each do |param|
                newresource[param].should == @resource[param]
            end
        end
    end

    describe "when converting to a RAL resource" do
        before do
            @resource = Puppet::Resource.new("file", "/my/file")
            @resource["one"] = "test"
            @resource["two"] = "other"
        end

        it "should use the resource type's :create method to create the resource if the resource is of a builtin type" do
            type = mock 'resource type'
            type.expects(:new).with(@resource).returns(:myresource)
            Puppet::Type.expects(:type).with(@resource.type).returns(type)
            @resource.to_ral.should == :myresource
        end

        it "should convert to a component instance if the resource type is not of a builtin type" do
            component = mock 'component type'
            Puppet::Type::Component.expects(:new).with(@resource).returns "meh"

            Puppet::Type.expects(:type).with(@resource.type).returns(nil)
            @resource.to_ral.should == "meh"
        end
    end

    it "should be able to convert itself to Puppet code" do
        Puppet::Resource.new("one::two", "/my/file").should respond_to(:to_manifest)
    end

    describe "when converting to puppet code" do
        before do
            @resource = Puppet::Resource.new("one::two", "/my/file", :noop => true, :foo => %w{one two})
        end

        it "should print the type and title" do
            @resource.to_manifest.should be_include("one::two { '/my/file':\n")
        end

        it "should print each parameter, with the value single-quoted" do
            @resource.to_manifest.should be_include("    noop => 'true'")
        end

        it "should print array values appropriately" do
            @resource.to_manifest.should be_include("    foo => ['one','two']")
        end
    end

    it "should be able to convert itself to a TransObject instance" do
        Puppet::Resource.new("one::two", "/my/file").should respond_to(:to_trans)
    end

    describe "when converting to a TransObject" do
        describe "and the resource is not an instance of a builtin type" do
            before do
                @resource = Puppet::Resource.new("foo", "bar")
            end

            it "should return a simple TransBucket if it is not an instance of a builtin type" do
                bucket = @resource.to_trans
                bucket.should be_instance_of(Puppet::TransBucket)
                bucket.type.should == @resource.type
                bucket.name.should == @resource.title
            end

            it "should copy over the resource's file" do
                @resource.file = "/foo/bar"
                @resource.to_trans.file.should == "/foo/bar"
            end

            it "should copy over the resource's line" do
                @resource.line = 50
                @resource.to_trans.line.should == 50
            end
        end

        describe "and the resource is an instance of a builtin type" do
            before do
                @resource = Puppet::Resource.new("file", "bar")
            end

            it "should return a TransObject if it is an instance of a builtin resource type" do
                trans = @resource.to_trans
                trans.should be_instance_of(Puppet::TransObject)
                trans.type.should == "file"
                trans.name.should == @resource.title
            end

            it "should copy over the resource's file" do
                @resource.file = "/foo/bar"
                @resource.to_trans.file.should == "/foo/bar"
            end

            it "should copy over the resource's line" do
                @resource.line = 50
                @resource.to_trans.line.should == 50
            end

            # Only TransObjects support tags, annoyingly
            it "should copy over the resource's tags" do
                @resource.tag "foo"
                @resource.to_trans.tags.should == @resource.tags
            end

            it "should copy the resource's parameters into the transobject and convert the parameter name to a string" do
                @resource[:foo] = "bar"
                @resource.to_trans["foo"].should == "bar"
            end

            it "should be able to copy arrays of values" do
                @resource[:foo] = %w{yay fee}
                @resource.to_trans["foo"].should == %w{yay fee}
            end

            it "should reduce single-value arrays to just a value" do
                @resource[:foo] = %w{yay}
                @resource.to_trans["foo"].should == "yay"
            end

            it "should convert resource references into the backward-compatible form" do
                @resource[:foo] = Puppet::Resource::Reference.new(:file, "/f")
                @resource.to_trans["foo"].should == %w{file /f}
            end

            it "should convert resource references into the backward-compatible form even when within arrays" do
                @resource[:foo] = ["a", Puppet::Resource::Reference.new(:file, "/f")]
                @resource.to_trans["foo"].should == ["a", %w{file /f}]
            end
        end
    end
end
