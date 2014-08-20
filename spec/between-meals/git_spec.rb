# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
require_relative '../../between-meals/repo/git'
require_relative '../../between-meals/repo.rb'
require 'logger'

describe BetweenMeals::Repo::Git do
  let(:logger) do
    Logger.new('/dev/null')
  end

  FIXTURES = [
    {
      :name => 'empty filelists',
      :changes => '',
      :result => []
    },
    {
      :name => 'handle renames',
      :changes => 'R050 foo/bar/baz foo/bang/bong',
      :result => [
        { :status => :deleted, :path => 'bar/baz' },
        { :status => :modified, :path => 'bang/bong' },
      ],
    },
    {
      :name => 'handle type changes',
      :changes => 'T foo/bar/baz',
      :result => [
        { :status => :deleted, :path => 'bar/baz' },
        { :status => :modified, :path => 'bar/baz' },
      ],
    },
    {
      :name => 'handle additions',
      :changes => 'A foo/bar/baz',
      :result => [
        { :status => :modified, :path => 'bar/baz' },
      ],
    },
    {
      :name => 'handle deletes',
      :changes => 'D foo/bar/baz',
      :result => [
        { :status => :deleted, :path => 'bar/baz' },
      ],
    },
    {
      :name => 'handle modifications',
      :changes => 'M004 foo/bar/baz',
      :result => [
        { :status => :modified, :path => 'bar/baz' },
      ],
    },
    {
      :name => 'handle misc',
      :changes => <<EOS ,
R050 foo/bar/baz foo/bang/bong
D foo/bar/baz
C foo/bar/baz foo/bang/bong
EOS
      :result => [
        { :status => :deleted, :path => 'bar/baz' },
        { :status => :modified, :path => 'bang/bong' },
        { :status => :deleted, :path => 'bar/baz' },
        { :status => :modified, :path => 'bang/bong' },
      ],
    },
  ]

  FIXTURES.each do |fixture|
    it "should handle #{fixture[:name]}" do
      BetweenMeals::Repo::Git.any_instance.stub(:setup).and_return(true)
      git = BetweenMeals::Repo::Git.new('foo', logger)
      git.send(:parse_status, fixture[:changes]).
        should eq(fixture[:result])
    end
  end

end
